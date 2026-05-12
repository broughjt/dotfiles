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
        ;; 2. Space: tap for Space, hold for a navigation layer.
        ;;
        ;; Timing notes:
        ;; - Increase hold-time if normal taps become accidental holds.
        ;; - Decrease hold-time if held actions feel sluggish.
        ;; - Space uses tap-hold-press so the nav layer can activate as soon
        ;;   as you press the next key while Space is held. If this causes
        ;;   accidental nav while typing, try plain tap-hold or a longer hold-time.

        (defsrc)

        (defalias
          space-nav (tap-hold-press 200 200 spc (layer-while-held nav))
        )

        (deflayermap (base)
          caps esc
          spc  @space-nav
        )

        (deflayermap (nav)
          ;; Vim-style arrows on the home row.
          h left
          j down
          k up
          l rght

          ;; Nearby navigation/editing conveniences.
          u home
          i pgdn
          o pgup
          p end

          n C-left
          m C-right
          , C-S-tab
          . C-tab

          bspc del
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
