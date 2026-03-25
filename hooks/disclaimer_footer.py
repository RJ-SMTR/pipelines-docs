# -*- coding: utf-8 -*-
"""
MkDocs hook — Injeta rodapé com aviso legal em todas as páginas de documentação.

Configuração no mkdocs.yml:
    hooks:
      - hooks/disclaimer_footer.py

Ref: https://www.mkdocs.org/user-guide/configuration/#hooks
"""

import posixpath

# Páginas que NÃO recebem o rodapé (caminhos relativos à raiz de docs/)
EXCLUDE_PAGES = {"aviso_legal.md", "index.md"}

FOOTER_TEMPLATE = """\

---

!!! warning "Aviso Legal"

    :material-robot: *Este documento foi gerado automaticamente com auxílio de
    inteligência artificial.*

    Este documento possui caráter meramente técnico-descritivo e pode conter erros. Para mais
    informações, consulte o [Aviso Legal]({disclaimer_url}) completo.
"""


def _relative_url(from_page: str, to_page: str) -> str:
    """Calcula o caminho relativo entre duas páginas MkDocs."""
    from_dir = posixpath.dirname(from_page)
    return posixpath.relpath(to_page, from_dir)


def on_page_markdown(markdown, page, config, files, **kwargs):
    """Appenda o rodapé de disclaimer ao final do markdown de cada página."""
    src_path = page.file.src_path

    if src_path in EXCLUDE_PAGES:
        return markdown

    disclaimer_url = _relative_url(src_path, "aviso_legal.md")
    footer = FOOTER_TEMPLATE.format(disclaimer_url=disclaimer_url)

    return markdown + footer
