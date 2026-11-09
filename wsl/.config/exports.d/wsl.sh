# wsl — the WSL env fragment (dots/wsl metapackage; OPT-IN: the wsl
# package is deliberately NOT in stows.required — machines opt in with
# `make stow-wsl` and configure further per machine).
# Sourced by ~/.config/exports's exports.d loader in every shell on
# machines that stowed the package; guarded by check-wsl so a non-WSL
# host that opted in anyway stays clean.
if [ -x "$HOME/.local/bin/check-wsl" ] && "$HOME/.local/bin/check-wsl"; then
    export DISPLAY=localhost:0.0
    # VcXsrv/X11 through WSL: force software GL rendering.
    # LIBGL_ALWAYS_INDIRECT deliberately NOT set: indirect GLX through
    # VcXsrv segfaults wgpu/glutin and WebKit GL paths (alacritty and
    # luakit die with SIGSEGV at startup). LIBGL_ALWAYS_SOFTWARE alone
    # routes through llvmpipe and works.
    export LIBGL_ALWAYS_SOFTWARE=true
    # BROWSER -> the runtime-conditional wrapper (dots/wsl)
    export BROWSER="firefox"
    # Allows VS Code usage within the X11
    export DONT_PROMPT_WSL_INSTALL=true
fi
