void reportMissingDef(String? key, String? href, String methodName) {
  throw Exception([
    'Failed to find definition for $href',
    'This library only supports <defs> and xlink:href references that '
        'are defined ahead of their references.',
    'This error can be caused when the desired definition is defined after the element '
        'referring to it (e.g. at the end of the file), or defined in another file.',
    'This error is treated as non-fatal, but your SVG file will likely not render as intended',
  ].join('\n,'));
}
