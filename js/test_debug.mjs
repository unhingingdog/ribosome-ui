import { create_processor, feed } from "./output/telomere/Processor.js";

let ps = create_processor();
console.log("Initial ps:", ps);

let result1 = feed(ps, '{"key":');
console.log("After first feed:", JSON.stringify(result1, null, 2));
let [out, ps1] = result1;
console.log("out:", out, "ps1:", ps1);

let result2 = feed(ps1, '"val');
console.log("After second feed:", JSON.stringify(result2, null, 2));
let [out2, ps2] = result2;
console.log("out2:", out2, "ps2:", ps2);
