# Pure renderers: flat attrset -> `key = value` lines, sorted by key.
let
  render = pkgs: name: settings: let
    inherit (pkgs) lib;
    value = v:
      if builtins.isBool v
      then
        (
          if v
          then "True"
          else "False"
        )
      # toString renders 0.35 as 0.350000; toJSON keeps the shortest form.
      else if builtins.isFloat v
      then builtins.toJSON v
      else toString v;
  in
    pkgs.writeText name (lib.generators.toKeyValue {
        mkKeyValue = k: v: "${k} = ${value v}";
      }
      settings);
in {
  mkDxvkConf = pkgs: render pkgs "dxvk.conf";
  mkVkBasaltConf = pkgs: render pkgs "vkBasalt.conf";
}
