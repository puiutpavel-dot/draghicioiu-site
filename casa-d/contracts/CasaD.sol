// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Token de test, fara valoare. Oricine isi poate lua tokeni din "robinet".
contract MockUSDC {
    string public constant name = "Test USDC (Casa D)";
    string public constant symbol = "tUSDC";
    uint8 public constant decimals = 6;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    uint256 public constant FAUCET_AMOUNT = 1000e6;

    /// Da 1.000 tUSDC apelantului.
    function faucet() external {
        totalSupply += FAUCET_AMOUNT;
        balanceOf[msg.sender] += FAUCET_AMOUNT;
        emit Transfer(address(0), msg.sender, FAUCET_AMOUNT);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _move(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= value, "allowance");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - value;
        _move(from, to, value);
        return true;
    }

    function _move(address from, address to, uint256 value) internal {
        require(to != address(0), "zero address");
        require(balanceOf[from] >= value, "balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// Piete de predictii DA/NU, peer-to-peer (pariu mutual): castigatorii isi impart potul
/// proportional cu miza. Comisionul se ia doar din potul pierzator.
/// DOAR PENTRU TESTNET. Neauditat. Rezultatul este introdus manual de owner.
contract PredictionMarket {
    enum Outcome { Unresolved, Yes, No, Invalid }

    struct Market {
        string category;
        string question;
        uint64 closeTime;
        Outcome outcome;
        uint256 yesPool;
        uint256 noPool;
    }

    struct Bet {
        uint32 marketId;
        address user;
        bool yes;
        uint64 time;
        uint256 amount;
    }

    uint256 public constant MAX_FEE_BPS = 500;
    uint256 public constant RESOLVE_GRACE = 7 days;

    IERC20 public immutable token;
    address public owner;
    uint256 public immutable feeBps;
    uint256 public accruedFees;
    uint256 public totalVolume;
    uint256 public bettorCount;

    Market[] private _markets;
    Bet[] private _bets;
    mapping(uint256 => mapping(address => uint256)) public yesStake;
    mapping(uint256 => mapping(address => uint256)) public noStake;
    mapping(uint256 => mapping(address => bool)) public claimed;
    mapping(address => bool) private _seen;

    event MarketCreated(uint256 indexed id, string category, string question, uint64 closeTime);
    event BetPlaced(uint256 indexed id, address indexed user, bool yes, uint256 amount);
    event Resolved(uint256 indexed id, Outcome outcome);
    event Claimed(uint256 indexed id, address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "doar owner");
        _;
    }

    constructor(IERC20 token_, uint256 feeBps_) {
        require(feeBps_ <= MAX_FEE_BPS, "comision prea mare");
        token = token_;
        feeBps = feeBps_;
        owner = msg.sender;
    }

    function transferOwnership(address to) external onlyOwner {
        require(to != address(0), "zero address");
        owner = to;
    }

    function createMarket(string calldata category, string calldata question, uint64 closeTime)
        external onlyOwner returns (uint256 id)
    {
        require(closeTime > block.timestamp, "inchidere in trecut");
        require(bytes(question).length > 0, "fara intrebare");
        id = _markets.length;
        _markets.push(Market(category, question, closeTime, Outcome.Unresolved, 0, 0));
        emit MarketCreated(id, category, question, closeTime);
    }

    function bet(uint256 id, bool yes, uint256 amount) external {
        Market storage m = _markets[id];
        require(block.timestamp < m.closeTime, "piata inchisa");
        require(m.outcome == Outcome.Unresolved, "piata rezolvata");
        require(amount > 0, "suma zero");
        if (yes) { m.yesPool += amount; yesStake[id][msg.sender] += amount; }
        else { m.noPool += amount; noStake[id][msg.sender] += amount; }
        totalVolume += amount;
        if (!_seen[msg.sender]) { _seen[msg.sender] = true; bettorCount++; }
        _bets.push(Bet(uint32(id), msg.sender, yes, uint64(block.timestamp), amount));
        emit BetPlaced(id, msg.sender, yes, amount);
        require(token.transferFrom(msg.sender, address(this), amount), "transfer esuat");
    }

    function resolve(uint256 id, Outcome outcome) external onlyOwner {
        Market storage m = _markets[id];
        require(block.timestamp >= m.closeTime, "inca deschisa");
        require(m.outcome == Outcome.Unresolved, "deja rezolvata");
        require(outcome != Outcome.Unresolved, "rezultat invalid");
        _settle(id, m, outcome);
    }

    /// Daca owner-ul nu introduce rezultatul in 7 zile, oricine poate anula piata: toti isi iau miza inapoi.
    function cancelUnresolved(uint256 id) external {
        Market storage m = _markets[id];
        require(m.outcome == Outcome.Unresolved, "deja rezolvata");
        require(block.timestamp >= m.closeTime + RESOLVE_GRACE, "prea devreme");
        _settle(id, m, Outcome.Invalid);
    }

    function _settle(uint256 id, Market storage m, Outcome outcome) internal {
        // Fara nicio miza pe varianta castigatoare => piata devine Invalid (toti primesc miza inapoi).
        if (outcome == Outcome.Yes && m.yesPool == 0) outcome = Outcome.Invalid;
        if (outcome == Outcome.No && m.noPool == 0) outcome = Outcome.Invalid;
        m.outcome = outcome;
        if (outcome == Outcome.Yes) accruedFees += m.noPool * feeBps / 10000;
        else if (outcome == Outcome.No) accruedFees += m.yesPool * feeBps / 10000;
        emit Resolved(id, outcome);
    }

    function claimable(uint256 id, address user) public view returns (uint256) {
        Market storage m = _markets[id];
        if (m.outcome == Outcome.Unresolved || claimed[id][user]) return 0;
        uint256 y = yesStake[id][user];
        uint256 n = noStake[id][user];
        if (m.outcome == Outcome.Invalid) return y + n;
        (uint256 stake, uint256 winPool, uint256 losePool) =
            m.outcome == Outcome.Yes ? (y, m.yesPool, m.noPool) : (n, m.noPool, m.yesPool);
        if (stake == 0) return 0;
        uint256 distributable = losePool - losePool * feeBps / 10000;
        return stake + distributable * stake / winPool;
    }

    function claim(uint256 id) external {
        uint256 due = claimable(id, msg.sender);
        require(due > 0, "nimic de revendicat");
        claimed[id][msg.sender] = true;
        emit Claimed(id, msg.sender, due);
        require(token.transfer(msg.sender, due), "transfer esuat");
    }

    function withdrawFees() external onlyOwner {
        uint256 f = accruedFees;
        accruedFees = 0;
        require(token.transfer(owner, f), "transfer esuat");
    }

    // ---- citire pentru interfata ----

    function marketCount() external view returns (uint256) { return _markets.length; }
    function betCount() external view returns (uint256) { return _bets.length; }
    function getMarkets() external view returns (Market[] memory) { return _markets; }

    /// Ultimele `n` mize, cea mai noua prima.
    function getRecentBets(uint256 n) external view returns (Bet[] memory out) {
        uint256 len = _bets.length;
        if (n > len) n = len;
        out = new Bet[](n);
        for (uint256 i; i < n; i++) out[i] = _bets[len - 1 - i];
    }

    /// Pozitiile unui utilizator pe toate pietele.
    function positions(address user)
        external view
        returns (uint256[] memory yes, uint256[] memory no, uint256[] memory due, bool[] memory done)
    {
        uint256 len = _markets.length;
        yes = new uint256[](len); no = new uint256[](len); due = new uint256[](len); done = new bool[](len);
        for (uint256 i; i < len; i++) {
            yes[i] = yesStake[i][user];
            no[i] = noStake[i][user];
            due[i] = claimable(i, user);
            done[i] = claimed[i][user];
        }
    }
}
