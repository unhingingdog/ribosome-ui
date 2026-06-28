module Log = struct

let log_level () : int = [%mel.raw {|
  (() => {
    if (typeof window !== 'undefined' && window.__DEBUG__) return window.__DEBUG__;
    if (typeof process !== 'undefined' && process.env.__DEBUG__) return Number(process.env.__DEBUG__);
    return 0;
  })()
|}]

let debug label detail =
  if log_level () >= 1 then Js.Console.log label;
  if log_level () >= 2 then Js.Console.log2 label detail

let debug1 label =
  if log_level () >= 1 then Js.Console.log label

end


