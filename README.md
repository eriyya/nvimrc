## Neovim config

## Requirements

**Neovim >=0.11.3 (only tested on 0.11.3)**

**Dependencies**
- Ripgrep
- fd
- Python3
- NodeJS
- Yarn
- fzf
- gzip & unzip

### Windows things

Install requirements with Chocolatey or winget etc:  
`choco install -y git ripgrep wget fd unzip gzip mingw make`

### Commands

- `:NeorgWorkspace` - Swap between Neorg workspaces via a telescope dropdown
- `:NeorgMarkdown` - Previews a Neorg file as a markdown file using markdown-preview.nvim

## Terminal stuff

Currently using [Wezterm](https://github.com/wez/wezterm)

### Fonts

[Iosevka](https://typeof.net/Iosevka/)

<details>
<summary>My Iosevka Config</summary>

```toml
[buildPlans.IosevkaRvn]
family = "Iosevka Rvn"
spacing = "normal"
serifs = "sans"
noCvSs = true
exportGlyphNames = false

[buildPlans.IosevkaRvn.variants.design]
one = "no-base"
zero = "slashed"
braille-dot = "round"
asterisk = "penta-high"
paren = "flat-arc"
brace = "curly-flat-boundary"
lig-neq = "more-slanted"
lig-equal-chain = "with-notch"
lig-hyphen-chain = "with-notch"
lig-double-arrow-bar = "without-notch"

[buildPlans.IosevkaRvn.weights.Light]
shape = 300
menu = 300
css = 300

[buildPlans.IosevkaRvn.weights.Regular]
shape = 400
menu = 400
css = 400

[buildPlans.IosevkaRvn.weights.Medium]
shape = 500
menu = 500
css = 500

[buildPlans.IosevkaRvn.weights.SemiBold]
shape = 600
menu = 600
css = 600

[buildPlans.IosevkaRvn.weights.Bold]
shape = 700
menu = 700
css = 700

[buildPlans.IosevkaRvn.widths.Normal]
shape = 500
menu = 5
css = "normal"

[buildPlans.IosevkaRvn.widths.Extended]
shape = 600
menu = 7
css = "expanded"

[buildPlans.IosevkaRvn.widths.Condensed]
shape = 416
menu = 3
css = "condensed"

[buildPlans.IosevkaRvn.widths.SemiCondensed]
shape = 456
menu = 4
css = "semi-condensed"

[buildPlans.IosevkaRvn.widths.SemiExtended]
shape = 548
menu = 6
css = "semi-expanded"

```

</details>
