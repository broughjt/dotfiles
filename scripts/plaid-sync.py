#!/usr/bin/env python3
"""Export bank transactions from Plaid to JSON.

    plaid-sync.py find goldenwest    # is an institution supported?
    plaid-sync.py link               # one-time browser connection
    plaid-sync.py sync               # incremental pull

Credentials come from the environment: PLAID_CLIENT_ID plus either
PLAID_SECRET or PLAID_SECRET_FILE (a path, for agenix). Failing that, an
env file of KEY=VALUE lines is read from --env-file.
"""

from __future__ import annotations

import argparse
import json
import os
import time
import webbrowser
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator, NoReturn

import plaid
from dotenv import dotenv_values
from platformdirs import PlatformDirs
from plaid.api import plaid_api
from plaid.model.accounts_get_request import AccountsGetRequest
from plaid.model.country_code import CountryCode
from plaid.model.institutions_search_request import InstitutionsSearchRequest
from plaid.model.institutions_search_request_options import (
    InstitutionsSearchRequestOptions,
)
from plaid.model.item_public_token_exchange_request import (
    ItemPublicTokenExchangeRequest,
)
from plaid.model.item_remove_request import ItemRemoveRequest
from plaid.model.link_token_create_hosted_link import LinkTokenCreateHostedLink
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.link_token_get_request import LinkTokenGetRequest
from plaid.model.link_token_transactions import LinkTokenTransactions
from plaid.model.products import Products
from plaid.model.transactions_sync_request import TransactionsSyncRequest


ENVIRONMENTS = {
    "production": plaid.Environment.Production,
    "sandbox": plaid.Environment.Sandbox,
}
PAGE_SIZE = 500
POLL_SECONDS = 3
POLL_TIMEOUT_SECONDS = 15 * 60

PLATFORM_DIRECTORIES = PlatformDirs("plaid-sync")
DEFAULT_STATE = PLATFORM_DIRECTORIES.user_state_path / "state.json"
DEFAULT_OUTPUT = PLATFORM_DIRECTORIES.user_data_path / "transactions.json"
DEFAULT_ENV_FILE = PLATFORM_DIRECTORIES.user_config_path / "plaid.env"


def main() -> int:
    parser = build_parser()
    arguments = parser.parse_args()
    return arguments.handler(arguments)


# Subcommands


def command_find(arguments: argparse.Namespace) -> int:
    client = build_client(arguments.env_file)
    request = InstitutionsSearchRequest(
        query=arguments.query,
        products=[Products("transactions")],
        country_codes=[CountryCode("US")],
        options=InstitutionsSearchRequestOptions(include_optional_metadata=True),
    )
    with handle_plaid_api_errors():
        response = client.institutions_search(request)

    institutions = response.to_dict().get("institutions", [])
    if not institutions:
        print(f"No transactions-capable institution matched {arguments.query!r}.")
        return 1

    for institution in institutions:
        print(institution["name"])
        print(f"  institution_id: {institution['institution_id']}")
        print(f"  auth:           {'OAuth' if institution.get('oauth') else 'credentials'}")
    return 0


def command_link(arguments: argparse.Namespace) -> int:
    client = build_client(arguments.env_file)

    request = LinkTokenCreateRequest(
        client_name="Personal Transaction Export",
        country_codes=[CountryCode("US")],
        language="en",
        user=LinkTokenCreateRequestUser(client_user_id="local-user"),
        products=[Products("transactions")],
        hosted_link=LinkTokenCreateHostedLink(),
        # Plaid backfills only 90 days unless asked; 730 is the maximum.
        transactions=LinkTokenTransactions(days_requested=arguments.days),
    )
    with handle_plaid_api_errors():
        created = client.link_token_create(request).to_dict()

    hosted_url = created.get("hosted_link_url")
    if not hosted_url:
        die("Plaid did not return a hosted_link_url")

    print(f"Open this URL to connect your bank:\n\n  {hosted_url}\n")
    webbrowser.open(hosted_url)
    print("Waiting for you to finish (Ctrl-C to abort)", end="", flush=True)

    item = None
    deadline = time.monotonic() + POLL_TIMEOUT_SECONDS
    get_request = LinkTokenGetRequest(link_token=created["link_token"])
    try:
        while item is None and time.monotonic() < deadline:
            time.sleep(POLL_SECONDS)
            with handle_plaid_api_errors():
                session_response = client.link_token_get(get_request).to_dict()
            for session in session_response.get("link_sessions") or []:
                for result in (session.get("results") or {}).get("item_add_results") or []:
                    if result.get("public_token"):
                        item = result
            print(".", end="", flush=True)
    except KeyboardInterrupt:
        print("\nAborted.")
        return 1
    print()

    if item is None:
        die("timed out waiting for the Link session; re-run `link` to try again")

    with handle_plaid_api_errors():
        exchange = client.item_public_token_exchange(
            ItemPublicTokenExchangeRequest(public_token=item["public_token"])
        ).to_dict()
        accounts = client.accounts_get(
            AccountsGetRequest(access_token=exchange["access_token"])
        ).to_dict()

    institution = item.get("institution") or {}
    state = load_state(arguments.state)
    state["items"][exchange["item_id"]] = {
        "access_token": exchange["access_token"],
        "institution_name": institution.get("name", "unknown"),
        "institution_id": institution.get("institution_id"),
        "cursor": None,
    }
    save_state(arguments.state, state)

    print(f"Connected: {institution.get('name', 'unknown')}")
    for account in accounts["accounts"]:
        print(f"  {account['name']} ({account.get('subtype')}) ****{account.get('mask') or '????'}")
    print(f"\nSaved to {arguments.state}. Next: plaid-sync.py sync")
    return 0


def command_unlink(arguments: argparse.Namespace) -> int:
    """Release an Item back to Plaid and drop its transactions from the store."""
    state = load_state(arguments.state)
    items = state["items"]
    if not items:
        die(f"nothing linked in {arguments.state}")

    if arguments.item_id:
        if arguments.item_id not in items:
            die(f"no such item {arguments.item_id!r}; have {', '.join(items)}")
        item_id = arguments.item_id
    elif len(items) == 1:
        item_id = next(iter(items))
    else:
        die("several items linked; pass one of: " + ", ".join(items))

    item = items[item_id]
    client = build_client(arguments.env_file)

    # Read the accounts before removing, so we know what to prune afterwards.
    with handle_plaid_api_errors():
        accounts = client.accounts_get(
            AccountsGetRequest(access_token=item["access_token"])
        ).to_dict()
    account_ids = {account["account_id"] for account in accounts["accounts"]}

    with handle_plaid_api_errors():
        client.item_remove(ItemRemoveRequest(access_token=item["access_token"]))

    del items[item_id]
    save_state(arguments.state, state)

    store = load_transactions(arguments.output)
    pruned = [
        transaction_id
        for transaction_id, record in store.items()
        if record.get("account_id") in account_ids
    ]
    for transaction_id in pruned:
        del store[transaction_id]
    save_transactions(arguments.output, store)
    total = len(store.values())

    print(f"Removed {item['institution_name']} ({item_id})")
    print(f"  pruned {len(pruned)} transactions, {total} remain in {arguments.output}")
    return 0


def command_sync(arguments: argparse.Namespace) -> int:
    state = load_state(arguments.state)
    if not state["items"]:
        die(f"no linked accounts in {arguments.state}; run `plaid-sync.py link` first")

    client = build_client(arguments.env_file)
    store = load_transactions(arguments.output)
    for item in state["items"].values():
        sync_item(client, item, store)

    save_state(arguments.state, state)
    save_transactions(arguments.output, store)
    total = len(store.values())
    print(f"\n{total} transactions -> {arguments.output}")
    return 0


# Credentials and Plaid client


def build_client(env_file: Path) -> plaid_api.PlaidApi:
    """Environment wins over the env file, so the nix module can override."""
    values = dotenv_values(env_file)

    def setting(name: str, default: str = "") -> str:
        return os.environ.get(name) or values.get(name) or default

    client_id = setting("PLAID_CLIENT_ID")
    secret = setting("PLAID_SECRET")
    secret_file = setting("PLAID_SECRET_FILE")
    environment = setting("PLAID_ENV", "production")

    if secret_file and not secret:
        path = Path(secret_file)
        if not path.exists():
            die(f"PLAID_SECRET_FILE points at {path}, which does not exist")
        secret = path.read_text().strip()

    if not client_id or not secret:
        die(
            "missing credentials. Set PLAID_CLIENT_ID and PLAID_SECRET "
            f"(or PLAID_SECRET_FILE), or put them in {env_file}"
        )
    if environment not in ENVIRONMENTS:
        die(f"PLAID_ENV must be one of {sorted(ENVIRONMENTS)}, got {environment!r}")

    configuration = plaid.Configuration(
        host=ENVIRONMENTS[environment],
        api_key={"clientId": client_id, "secret": secret},
    )
    return plaid_api.PlaidApi(plaid.ApiClient(configuration))


@contextmanager
def handle_plaid_api_errors() -> Iterator[None]:
    """Turn Plaid's ApiException into a readable one-line message."""
    try:
        yield
    except plaid.ApiException as error:
        try:
            body = json.loads(error.body)
        except (json.JSONDecodeError, TypeError):
            die(f"Plaid error (HTTP {error.status}): {error.body}")
        message = f"{body.get('error_code')}: {body.get('error_message')}"
        if body.get("error_code") == "INVALID_API_KEYS":
            message += "\n  Does PLAID_ENV match the secret you configured?"
        die(message)


def sync_item(client, item: dict, store: dict[str, dict]) -> None:
    """Drain the sync feed for one institution, applying deltas to the store."""
    with handle_plaid_api_errors():
        accounts = client.accounts_get(
            AccountsGetRequest(access_token=item["access_token"])
        ).to_dict()
    account_names = {a["account_id"]: a["name"] for a in accounts["accounts"]}

    cursor = item.get("cursor")
    added = modified = removed = 0

    while True:
        parameters: dict[str, Any] = {
            "access_token": item["access_token"],
            "count": PAGE_SIZE,
        }
        if cursor:
            parameters["cursor"] = cursor
        with handle_plaid_api_errors():
            page = client.transactions_sync(TransactionsSyncRequest(**parameters)).to_dict()

        for transaction in page["added"] + page["modified"]:
            # Keep Plaid's full record; only denormalize the account name in.
            record = json.loads(json.dumps(transaction, default=str))
            record["account_name"] = account_names.get(record["account_id"], "")
            known = record["transaction_id"] in store
            store[record["transaction_id"]] = record
            modified += known
            added += not known
        for transaction in page["removed"]:
            removed += store.pop(transaction["transaction_id"], None) is not None

        cursor = page["next_cursor"]
        if not page["has_more"]:
            break

    item["cursor"] = cursor
    print(f"  {item['institution_name']}: +{added} added, ~{modified} modified, -{removed} removed")


# On-disk state and output


def load_state(path: Path) -> dict[str, Any]:
    if path.exists():
        return json.loads(path.read_text())
    return {"items": {}}


def save_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, default=str))
    path.chmod(0o600) # holds access tokens


def load_transactions(path: Path) -> dict[str, dict]:
    """Read the output file back as an id -> transaction index."""
    if not path.exists():
        return {}
    return {row["transaction_id"]: row for row in json.loads(path.read_text())}


def save_transactions(path: Path, store: dict[str, dict]):
    rows = sorted(store.values(), key=lambda row: (row.get("date") or "", row.get("name") or ""))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, indent=2, default=str))


# Command-line parsing


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        # Without `prog`, argparse reports the nix store path it was invoked from.
        prog="plaid-sync",
        description="Export bank transactions from Plaid to JSON.",
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        default=DEFAULT_ENV_FILE,
        help=f"KEY=VALUE credentials file (default: {DEFAULT_ENV_FILE})",
    )
    parser.add_argument(
        "--state",
        type=Path,
        default=DEFAULT_STATE,
        help=f"access tokens and sync cursors (default: {DEFAULT_STATE})",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    find = subparsers.add_parser("find", help="check whether an institution is supported")
    find.add_argument("query", help="institution name, or part of one")
    find.set_defaults(handler=command_find)

    link = subparsers.add_parser("link", help="connect a bank (one-time, opens a browser)")
    link.add_argument(
        "--days",
        type=int,
        default=730,
        help="days of history to request, 1-730 (default: 730)",
    )
    link.set_defaults(handler=command_link)

    sync = subparsers.add_parser("sync", help="pull new transactions")
    sync.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"transactions JSON (default: {DEFAULT_OUTPUT})",
    )
    sync.set_defaults(handler=command_sync)

    unlink = subparsers.add_parser(
        "unlink", help="disconnect a bank and prune its transactions"
    )
    unlink.add_argument(
        "item_id", nargs="?", help="item to remove (optional if only one is linked)"
    )
    unlink.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"transactions JSON (default: {DEFAULT_OUTPUT})",
    )
    unlink.set_defaults(handler=command_unlink)

    return parser


# Utilities


def die(message: str) -> NoReturn:
    raise SystemExit(f"plaid-sync: {message}")


if __name__ == "__main__":
    raise SystemExit(main())
