// Teste pe un lant local (ganache, in proces).
const ganache = require("ganache"), { ethers } = require("ethers"), assert = require("assert");
const art = require("./artifacts.json");

(async () => {
  const g = ganache.provider({ logging: { quiet: true }, chain: { hardfork: "merge" }, wallet: { totalAccounts: 6 } });
  const provider = new ethers.BrowserProvider(g, undefined, { cacheTimeout: -1 });
  const [owner, ana, bogdan, cristi, dan] = await Promise.all([0, 1, 2, 3, 4].map(i => provider.getSigner(i)));
  const U = n => ethers.parseUnits(String(n), 6);
  const now = async () => Number((await g.request({ method: "eth_getBlockByNumber", params: ["latest", false] })).timestamp);
  const warp = async s => { const t = await now(); await g.request({ method: "evm_mine", params: [{ timestamp: t + s }] }); if (process.env.DBG) console.log("warp", t, "->", await now()); };
  const fails = async (p, why) => { try { await (await p).wait(); } catch (e) { const txt = String(e.message) + JSON.stringify(e.info || {}, (k, v) => typeof v === "bigint" ? String(v) : v) + JSON.stringify(e.data || ""); if (process.env.DBG) console.log("caught", why, "|", e.shortMessage); if (why) assert(txt.includes(why), "motiv gresit (" + why + "): " + txt.slice(0, 600)); return; } assert.fail("trebuia sa esueze: " + why); };

  async function fresh(fee = 200) {
    const usdc = await (await new ethers.ContractFactory(art.MockUSDC.abi, art.MockUSDC.bytecode, owner).deploy()).waitForDeployment();
    const pm = await (await new ethers.ContractFactory(art.PredictionMarket.abi, art.PredictionMarket.bytecode, owner).deploy(await usdc.getAddress(), fee)).waitForDeployment();
    for (const s of [ana, bogdan, cristi, dan]) {
      await (await usdc.connect(s).faucet()).wait();
      await (await usdc.connect(s).approve(await pm.getAddress(), ethers.MaxUint256)).wait();
    }
    return { usdc, pm };
  }
  const bal = (usdc, s) => s.getAddress().then(a => usdc.balanceOf(a));
  let n = 0; const ok = name => console.log("  ok " + (++n) + " " + name);

  // 1. flux normal: DA castiga
  {
    const { usdc, pm } = await fresh();
    const t = await now();
    await (await pm.createMarket("SUPERLIGA", "Castiga gazdele?", t + 1000)).wait();
    await (await pm.connect(ana).bet(0, true, U(100))).wait();
    await (await pm.connect(bogdan).bet(0, false, U(300))).wait();
    await (await pm.connect(cristi).bet(0, true, U(300))).wait();
    await fails(pm.resolve(0, 1), "inca deschisa");
    await fails(pm.connect(ana).claim(0), "nimic de revendicat");
    await warp(1001);
    await fails(pm.connect(ana).bet(0, true, U(1)), "piata inchisa");
    await fails(pm.connect(ana).resolve(0, 1), "doar owner");
    await (await pm.resolve(0, 1)).wait();
    await fails(pm.resolve(0, 2), "deja rezolvata");
    // pot pierzator 300, comision 6, distribuibil 294; ana 100/400 -> 73.5; cristi 300/400 -> 220.5
    assert.equal(await pm.claimable(0, await ana.getAddress()), U(173.5));
    assert.equal(await pm.claimable(0, await cristi.getAddress()), U(520.5));
    assert.equal(await pm.claimable(0, await bogdan.getAddress()), 0n);
    await (await pm.connect(ana).claim(0)).wait();
    await fails(pm.connect(ana).claim(0), "nimic de revendicat");
    await (await pm.connect(cristi).claim(0)).wait();
    await fails(pm.connect(bogdan).claim(0), "nimic de revendicat");
    assert.equal(await bal(usdc, ana), U(1073.5));
    assert.equal(await bal(usdc, cristi), U(1220.5));
    assert.equal(await pm.accruedFees(), U(6));
    await (await pm.withdrawFees()).wait();
    assert.equal(await bal(usdc, owner), U(6));
    assert.equal(await usdc.balanceOf(await pm.getAddress()), 0n);
    ok("DA castiga: plati, comision doar din potul pierzator, contract golit exact");

    // citire pentru interfata
    const ms = await pm.getMarkets();
    assert.equal(ms.length, 1); assert.equal(ms[0].question, "Castiga gazdele?"); assert.equal(ms[0].yesPool, U(400));
    const bs = await pm.getRecentBets(2);
    assert.equal(bs.length, 2); assert.equal(bs[0].user, await cristi.getAddress()); assert.equal(bs[1].yes, false);
    assert.equal((await pm.getRecentBets(99)).length, 3);
    assert.equal(await pm.betCount(), 3n); assert.equal(await pm.bettorCount(), 3n); assert.equal(await pm.totalVolume(), U(700));
    const pos = await pm.positions(await ana.getAddress());
    assert.equal(pos.yes[0], U(100)); assert.equal(pos.due[0], 0n); assert.equal(pos.done[0], true);
    ok("functiile de citire (piete, mize recente, statistici, pozitii)");
  }
  // 2. NU castiga + un utilizator pe ambele parti
  {
    const { usdc, pm } = await fresh();
    await (await pm.createMarket("", "Q", (await now()) + 100)).wait();
    await (await pm.connect(ana).bet(0, true, U(50))).wait();
    await (await pm.connect(ana).bet(0, false, U(50))).wait();
    await (await pm.connect(bogdan).bet(0, false, U(150))).wait();
    await warp(101);
    await (await pm.resolve(0, 2)).wait();
    // pierzator 50, comision 1, distribuibil 49; ana 50/200 -> 12.25 ; bogdan 150/200 -> 36.75
    assert.equal(await pm.claimable(0, await ana.getAddress()), U(62.25));
    assert.equal(await pm.claimable(0, await bogdan.getAddress()), U(186.75));
    assert.equal(await pm.bettorCount(), 2n);
    ok("NU castiga, utilizator cu mize pe ambele parti");
  }
  // 3. Invalid: toti isi iau miza, fara comision
  {
    const { usdc, pm } = await fresh();
    await (await pm.createMarket("", "Q", (await now()) + 100)).wait();
    await (await pm.connect(ana).bet(0, true, U(40))).wait();
    await (await pm.connect(bogdan).bet(0, false, U(60))).wait();
    await warp(101);
    await (await pm.resolve(0, 3)).wait();
    await (await pm.connect(ana).claim(0)).wait(); await (await pm.connect(bogdan).claim(0)).wait();
    assert.equal(await bal(usdc, ana), U(1000)); assert.equal(await bal(usdc, bogdan), U(1000));
    assert.equal(await pm.accruedFees(), 0n);
    ok("Invalid: rambursare integrala, fara comision");
  }
  // 4. nimeni pe varianta castigatoare -> Invalid
  {
    const { usdc, pm } = await fresh();
    await (await pm.createMarket("", "Q", (await now()) + 100)).wait();
    await (await pm.connect(ana).bet(0, false, U(40))).wait();
    await warp(101);
    await (await pm.resolve(0, 1)).wait();
    assert.equal((await pm.getMarkets())[0].outcome, 3n);
    await (await pm.connect(ana).claim(0)).wait();
    assert.equal(await bal(usdc, ana), U(1000));
    ok("fara mize pe varianta castigatoare: devine Invalid");
  }
  // 5. cancelUnresolved dupa 7 zile
  {
    const { usdc, pm } = await fresh();
    await (await pm.createMarket("", "Q", (await now()) + 100)).wait();
    await (await pm.connect(ana).bet(0, true, U(40))).wait();
    await warp(101);
    await fails(pm.connect(bogdan).cancelUnresolved(0), "prea devreme");
    await warp(7 * 86400);
    await (await pm.connect(bogdan).cancelUnresolved(0)).wait();
    await (await pm.connect(ana).claim(0)).wait();
    assert.equal(await bal(usdc, ana), U(1000));
    ok("anulare de catre oricine dupa 7 zile fara rezultat");
  }
  // 6. validari
  {
    const { usdc, pm } = await fresh();
    const t = await now();
    await fails(pm.createMarket("", "Q", t - 1), "inchidere in trecut");
    await fails(pm.createMarket("", "", t + 100), "fara intrebare");
    await fails(pm.connect(ana).createMarket("", "Q", t + 100), "doar owner");
    await (await pm.createMarket("", "Q", t + 100)).wait();
    await fails(pm.connect(ana).bet(0, true, 0), "suma zero");
    await fails(pm.connect(ana).bet(0, true, U(5000)), "balance");
    await fails(pm.connect(ana).bet(7, true, U(1)));
    await fails(pm.connect(ana).withdrawFees(), "doar owner");
    await fails(new ethers.ContractFactory(art.PredictionMarket.abi, art.PredictionMarket.bytecode, owner).deploy(await usdc.getAddress(), 501).then(c => c.deploymentTransaction()), "comision prea mare");
    ok("validari si drepturi");
  }
  // 7. fuzz: solvabilitate, castigatorii nu pierd niciodata
  {
    const rnd = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
    for (let round = 0; round < 40; round++) {
      const { usdc, pm } = await fresh(rnd(0, 500));
      await (await pm.createMarket("", "Q", (await now()) + 1000)).wait();
      const users = [ana, bogdan, cristi, dan], stakes = users.map(() => [0n, 0n]);
      const nb = rnd(1, 7);
      for (let i = 0; i < nb; i++) {
        const u = rnd(0, 3), yes = Math.random() < .5, amt = BigInt(rnd(1, 200000000));
        if (stakes[u][0] + stakes[u][1] + amt > U(1000)) continue;
        await (await pm.connect(users[u]).bet(0, yes, amt)).wait();
        stakes[u][yes ? 0 : 1] += amt;
      }
      await warp(1001);
      const want = rnd(1, 3);
      await (await pm.resolve(0, want)).wait();
      const out = Number((await pm.getMarkets())[0].outcome);
      let paid = 0n, total = 0n;
      for (let u = 0; u < 4; u++) {
        total += stakes[u][0] + stakes[u][1];
        const due = await pm.claimable(0, await users[u].getAddress());
        const winStake = out === 3 ? stakes[u][0] + stakes[u][1] : stakes[u][out === 1 ? 0 : 1];
        if (winStake > 0n) assert(due >= winStake, "castigator sub miza"); else assert.equal(due, 0n);
        if (due > 0n) { await (await pm.connect(users[u]).claim(0)).wait(); paid += due; }
      }
      if ((await pm.accruedFees()) > 0n) await (await pm.withdrawFees()).wait();
      const left = await usdc.balanceOf(await pm.getAddress());
      assert(paid + (await bal(usdc, owner)) + left === total, "bani creati sau pierduti");
      assert(left <= 8n, "ramane prea mult praf: " + left);
    }
    ok("fuzz 40 runde: solvabil, castigatorii primesc cel putin miza, doar praf din rotunjiri");
  }
  console.log("TOATE TESTELE AU TRECUT (" + n + ")");
  await g.disconnect();
})().catch(e => { console.error("ESEC:", e); process.exit(1); });
