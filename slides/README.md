# Workshop Slides

Marp-compatible Markdown presentations (one per section). Each slide deck:
- Opens the section with a **journey map** showing progress through the workshop
- Explains the **component diagram** for that section (what's running, what connects to what)
- Shows **expected outputs** so participants know what success looks like
- Ends with a **transition** to the next section

---

## Files

| File | Section | When to show |
|:-----|:--------|:------------|
| `00-opening.md` | Opening | Before Section 01 `setup.sh` |
| `01-setup-slides.md` | Setup | Immediately before participants run `setup.sh` |
| `02-local-eval-slides.md` | Local evaluation | Before Track A; again before Track B |
| `03-irr-slides.md` | IRR benchmark | After the break. Before Section 03 |
| `04-compare-slides.md` | Act 3: Side-by-Side Comparison | Before Section 04 |

---

## Rendering

```bash
# Install Marp CLI
npm install -g @marp-team/marp-cli

# Render a single section to HTML
marp slides/00-opening.md

# Render all to HTML
for f in slides/*.md; do marp "$f"; done

# Present with live reload
marp --watch --server slides/

# Export to PDF
marp slides/00-opening.md --pdf
```

---

## Without Marp

- The slides are readable as plain Markdown. Each slide is separated by `---`. 
- You can copy the content into any slide tool (Google Slides, PowerPoint, Keynote).
- The diagrams are ASCII and the tables transfer cleanly.

---

## Design Notes

- **Dark theme** use `#0f0f1a` (readable in conference rooms with variable lighting)
- **Red Hat brand colours** 
    - `#ee0000` (Red Hat red)  |  `#f5a623` (orange)  |  `#7bc8f6` (light blue)
- **Code blocks** use Catppuccin Mocha palette (`#1e1e2e` background) for syntax contrast
- **Fonts** Red Hat Text → Segoe UI → system sans-serif (no external dependencies)
