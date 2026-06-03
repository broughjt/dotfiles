pkgs:

pkgs.buildNpmPackage rec {
  pname = "pi-mcp-adapter";
  version = "2.8.0";

  src = pkgs.fetchFromGitHub {
    owner = "nicobailon";
    repo = "pi-mcp-adapter";
    rev = "1091b34da83d58bd2d9fcaff2dc31f449a94bf1f";
    hash = "sha256-eHz/uivSIZ8HOalSCZgyCyOWodQJq5GapAqpT2ryn1k=";
  };

  npmDepsHash = "sha256-rga1WzbUKgIXFJlC6K5zmVHSjN8QeFovtfAX17BSjlw=";
  postPatch = ''
    cp ${../../pi/pi-mcp-adapter-package-lock.json} package-lock.json

    substituteInPlace config.ts \
      --replace-fail 'return overridePath ? resolve(overridePath) : getAgentPath("mcp.json");' \
                     'const envPath = process.env.PI_MCP_CONFIG?.trim(); return overridePath ? resolve(overridePath) : envPath ? resolve(envPath) : getAgentPath("mcp.json");'

    substituteInPlace metadata-cache.ts \
      --replace-fail 'import { dirname } from "node:path";' \
                     'import { dirname, resolve } from "node:path";' \
      --replace-fail 'return getAgentPath("mcp-cache.json");' \
                     'const envPath = process.env.PI_MCP_CACHE?.trim(); return envPath ? resolve(envPath) : getAgentPath("mcp-cache.json");'

    substituteInPlace onboarding-state.ts \
      --replace-fail 'import { dirname } from "node:path";' \
                     'import { dirname, resolve } from "node:path";' \
      --replace-fail 'return getAgentPath("mcp-onboarding.json");' \
                     'const envPath = process.env.PI_MCP_ONBOARDING_STATE?.trim(); return envPath ? resolve(envPath) : getAgentPath("mcp-onboarding.json");'

    substituteInPlace cli.js \
      --replace-fail 'const PI_CONFIG_PATH = path.join(AGENT_DIR, "mcp.json");' \
                     'const PI_CONFIG_PATH = process.env.PI_MCP_CONFIG?.trim() ? expandHome(process.env.PI_MCP_CONFIG.trim()) : path.join(AGENT_DIR, "mcp.json");'
  '';
  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r \
      cli.js \
      agent-dir.ts \
      index.ts \
      state.ts \
      utils.ts \
      tool-metadata.ts \
      init.ts \
      ui-session.ts \
      proxy-modes.ts \
      direct-tools.ts \
      commands.ts \
      onboarding-state.ts \
      mcp-setup-panel.ts \
      types.ts \
      ui-stream-types.ts \
      config.ts \
      server-manager.ts \
      sampling-handler.ts \
      tool-registrar.ts \
      tool-result-renderer.ts \
      resource-tools.ts \
      lifecycle.ts \
      metadata-cache.ts \
      host-html-template.ts \
      ui-resource-handler.ts \
      consent-manager.ts \
      ui-server.ts \
      glimpse-ui.ts \
      npx-resolver.ts \
      oauth-handler.ts \
      mcp-auth.ts \
      mcp-oauth-provider.ts \
      mcp-callback-server.ts \
      mcp-auth-flow.ts \
      mcp-panel.ts \
      logger.ts \
      errors.ts \
      app-bridge.bundle.js \
      banner.png \
      package.json \
      README.md \
      CHANGELOG.md \
      LICENSE \
      node_modules \
      $out/
    runHook postInstall
  '';
}
