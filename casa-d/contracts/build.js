// Compileaza CasaD.sol -> abi.js (ABI + bytecode) pentru site.
const solc = require("solc"), fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "CasaD.sol"), "utf8");
const out = JSON.parse(solc.compile(JSON.stringify({
  language: "Solidity",
  sources: { "CasaD.sol": { content: src } },
  settings: { optimizer: { enabled: true, runs: 200 }, evmVersion: "paris",
    outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } } }
})));
const errs = (out.errors || []).filter(e => e.severity === "error");
(out.errors || []).forEach(e => console.log(e.severity + ": " + e.formattedMessage.split("\n")[0]));
if (errs.length) process.exit(1);
const c = out.contracts["CasaD.sol"];
const art = {};
for (const n of ["MockUSDC", "PredictionMarket"]) art[n] = { abi: c[n].abi, bytecode: "0x" + c[n].evm.bytecode.object };
fs.writeFileSync(path.join(__dirname, "artifacts.json"), JSON.stringify(art));
const dest = process.argv[2];
if (dest) fs.writeFileSync(dest, "/* Generat din CasaD.sol (solc 0.8.28). Nu edita manual. */\nwindow.CASAD_ART=" + JSON.stringify(art) + ";\n");
console.log("ok", Object.keys(art).map(n => n + ":" + (art[n].bytecode.length / 2 - 1) + "b").join(" "));
