{ ... }:

{
  services.kanata = {
    enable = true;
    keyboards.default = {
      # Empty/default devices lets kanata detect and intercept all keyboards.
      extraDefCfg = ''
        process-unmapped-keys yes
      '';

      config = ''
        ;; 1. Caps Lock: unconditionally Escape.
        ;;
        ;; TODO: Re-enable a Space navigation layer later. The previous version
        ;; used Space as normal Space on tap and a nav layer on hold, with
        ;; h/j/k/l as arrows and nearby navigation/editing conveniences.

        (defsrc)

        (deflayermap (base)
          caps esc
        )

        ;; TODO(#3): Try opposite-hand home-row mods once the basic layer-taps
        ;; feel solid.
        ;;   Kanata sample:
        ;;   https://github.com/jtroo/kanata/blob/main/cfg_samples/home-row-mod-prior-idle.kbd
        ;;   Tap-hold docs:
        ;;   https://github.com/jtroo/kanata/blob/main/docs/config.adoc#tap-hold
        ;;
        ;; TODO(#4): Consider more advanced tap-hold patterns later, e.g.
        ;; one-shot modifiers, tap-dance, symbol layers, or tap-hold letters
        ;; that switch to numbers/arrows/symbols layers.
        ;;   One-shot docs:
        ;;   https://github.com/jtroo/kanata/blob/main/docs/config.adoc#one-shot
        ;;   Tap-dance docs:
        ;;   https://github.com/jtroo/kanata/blob/main/docs/config.adoc#tap-dance
        ;;   Layer-tap sample:
        ;;   https://github.com/jtroo/kanata/blob/main/cfg_samples/jtroo.kbd
      '';
    };
  };
}
