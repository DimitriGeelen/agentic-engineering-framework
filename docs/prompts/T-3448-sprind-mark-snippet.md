# SPRIND mark — drop-in snippet

Self-contained. Nothing to download, no external file, no dependency on the
design system artifact. Paste as is.

Extracted 2026-09-24 from `https://www.sprind.org/en`, where the mark is an
**inline** `<svg>` (136×19, one compound path) — the site serves no standalone
logo file. Cleaned only: framework attributes and utility classes removed,
`viewBox` casing fixed, `role="img"` and `<title>` added. Geometry untouched.

## 1 — The mark

Save as `site/assets/sprind-wordmark.svg`, **or** inline it directly (inlining
is preferred: `currentColor` then follows the container, so one file serves both
light and dark grounds).

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 136 19" fill="currentColor" role="img" aria-label="SPRIND">
  <title>SPRIND</title>
  <path fill-rule="evenodd" clip-rule="evenodd" d="M10.3882 18.4073C16.3608 18.4073 19.754 16.3446 19.754 12.6411C19.754 9.57046 17.8715 8.21093 13.3164 7.74199L8.78463 7.27322C6.66976 7.06231 5.99588 6.66379 5.99588 5.65584C5.99588 4.50739 7.36707 3.89779 9.92344 3.89779C13.084 3.89779 15.4546 4.88227 16.663 6.5466L19.6376 4.03845C17.5693 1.69444 14.3158 0.592773 10.1558 0.592773C4.50851 0.592773 1.30137 2.56173 1.30137 5.86692C1.30137 8.93755 3.27678 10.4377 7.29726 10.883L12.3636 11.4455C14.3158 11.6566 15.0129 12.0784 15.0129 13.1099C15.0129 14.4224 13.6186 15.0553 10.6206 15.0553C7.25088 15.0553 4.71762 13.7193 3.3466 11.7738L0 14.1413C1.69649 16.7664 5.50785 18.4073 10.3882 18.4073ZM33.8589 1.18457H22.6572V17.8272H27.3517V12.553H33.7658C38.0188 12.553 40.761 10.2794 40.761 6.71657C40.761 3.27089 38.1814 1.18457 33.8589 1.18457ZM32.6976 9.3647H27.3525V4.37206H32.7208C34.6963 4.37206 35.8118 5.23935 35.8118 6.83326C35.8118 8.45064 34.6497 9.3647 32.6976 9.3647ZM56.6576 17.8272H61.9562L57.6568 11.4046C60.4224 10.4904 61.3519 8.31048 61.3519 6.45871C61.3519 3.9271 59.8182 1.18457 54.5194 1.18457H43.2714V17.8272H47.9659V11.9436H52.73L56.6576 17.8272ZM47.9676 4.34667H53.4522C55.7064 4.34667 56.3804 5.44834 56.3804 6.59696C56.3804 7.76888 55.7064 8.91749 53.4522 8.91749H47.9676V4.34667ZM64.7908 17.827H69.4853V1.18457H64.7908V17.827ZM73.7635 17.8272H78.0165V8.709V6.3883H78.1094C78.3651 6.92748 78.9926 7.7713 79.4341 8.28701L88.3349 17.8272H93.0061V1.18457H88.7533V10.1153V12.5063H88.6603C88.3582 11.8499 87.8934 11.2874 87.3588 10.631L78.7833 1.18457H73.7635V17.8272ZM96.2127 11.5638H112.364V7.76658H96.2127V11.5638ZM115.572 17.8272H125.96C131.886 17.8272 136 14.4048 136 9.22454C136 4.02099 132.119 1.18457 126.053 1.18457H115.572V17.8272ZM120.263 14.6116V4.39159H125.33C128.699 4.39159 131.023 6.05592 131.023 9.31416C131.023 12.6427 128.885 14.6116 125.353 14.6116H120.263Z"/>
</svg>
```

## 2 — The footer credit

```html
<div class="fw-credit">
  <span class="fw-mark"><!-- the SVG above, inlined --></span>
  <p class="fw-line">Gefördert in der SPRIND&nbsp;Challenge<br>„Deutschland, was geht?"</p>
</div>
```

```css
.fw-credit{
  display:flex; align-items:center; gap:22px; flex-wrap:wrap;
  padding:22px 0; border-top:1px solid var(--rule);
}
.fw-mark{ flex:none; width:136px; max-width:180px; color:var(--ink); }
.fw-mark svg{ display:block; width:100%; height:auto; }
.fw-line{
  margin:0; max-width:44ch;
  font-family:var(--font-mono); font-size:12px; line-height:19px;
  letter-spacing:.02em; color:var(--ink-2);
}
/* on an ink or blue-deep ground */
.fw-credit.on-ink .fw-mark{ color:var(--paper); }
.fw-credit.on-ink .fw-line{ color:var(--ink-mute); }
```

The mark takes its colour from `color` on `.fw-mark`, because the SVG is
`fill="currentColor"`. If you reference it as `<img src="…">` instead, that
stops working — an `<img>` cannot resolve `currentColor` — and you need two
fixed-ink copies, `#14202e` for light grounds and `#fbfaf7` for dark.

## 3 — The four limits

Binding, not stylistic:

1. **Footer only.** Never beside a finding; never on Die Liste, Die Belege or
   Die Struktur.
2. **Wordmark size** — 136×19 at 1×, never wider than 180px.
3. **Two inks only** — `ink` on light grounds, `paper` on dark. Never `blue`,
   `steel` or any evidence token: under this system those colours state how
   strong the evidence is, and a funder makes no claim about evidence.
4. **It says who funded the work** — never that SPRIND vouches for a finding.
   On a site whose headline number is zero-confirmed, that reading is the one
   thing a credit must not invite.

## 4 — Do not ship the wording yet

`„Gefördert in der SPRIND Challenge »Deutschland, was geht?«"` is factually
accurate per the project README, but the exact German funding formula is fixed
by SPRIND's corporate-design manual (their own asset filenames carry `CD`
prefixes). **Leave the slot ready and flag it; ship only wording the operator
has confirmed with SPRIND.**

Do not add SPRIND's BMFTR ministry lockup. That records who funds **SPRIND**,
not who funds Streichliste, and placing it here asserts a relationship with the
ministry that does not exist.

This file is correct as bytes. It is not an authorisation.
