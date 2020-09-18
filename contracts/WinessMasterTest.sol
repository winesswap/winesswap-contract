// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


import "./SafeERC20.sol";
import "./Wines.sol";


// Have fun reading it. Hopefully it's bug-free. God bless.
contract WinesMaster is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;   //LP TOKEN balance
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 weightPoint;
        uint256 share;
        uint256 lastRewardBlock;
    }

    struct PioneerInfo {
        uint256 poolId;
        uint256 endBlock;
        uint256 totalReward;
        uint256 blockReward;
        uint256 startBlock;
        uint256 rewardBalance;
        uint256 startRewardDebt;
        uint256 endRewardDebt;
    }

    // The GIFT TOKEN!
    WinesToken public giftToken;
    // the Owner address
    address public fundPool;
    // block interval for miner difficult update 
    uint256 public difficultyChangeBlock;
    // the reward of each block.
    uint256 public minerBlockReward;
    
    uint256 public currentDifficulty;
    // the reward for developer rato 
    uint256 public constant DEVELOPER_RATO = 10;
    uint256 public constant INTERVAL = 1e12;
    // the migrator token
    IMigratorToken public migrator;

    // Deposit pool array
    PoolInfo[] public poolInfoList;
    
    // userinfo map
    mapping (uint256 => mapping (address => UserInfo)) public userInfoMap;
    // pioneerInfo map
    mapping (uint256 => PioneerInfo) public pioneerInfoMap;
    // total alloc point
    uint256 public totalWeightPoint = 0;
    // miner start block
    uint256 public startBlock;
    // miner block num for test
    uint256 public testBlockNum;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(WinesToken _gift) public {
        giftToken = _gift;
        fundPool = address(msg.sender);
        startBlock = block.number;
        testBlockNum = block.number;
        minerBlockReward = 150 * 1e18;
    }
    
    function aSetStartBlock(uint256 _startBlock) public {
        startBlock = _startBlock;
    }
    
    function aSetMinerBlockReward(uint256 _minerBlockReward) public {
        minerBlockReward = _minerBlockReward;
    }
    
    function aSetBlockNum(uint256 _blockNum) public {
        testBlockNum = _blockNum;
    }
    
    
    // constructor(Winess _gift, uint256 _startBlock, uint256 _difficultyBlockInterval, uint256 _minerBlockReward, uint256 _fundPoolAddress) public {
    //     giftToken = _gift;
    //     fundPool = _fundPoolAddress;
    //     startBlock = _startBlock;
    //     difficultyBlockInterval = _difficultyBlockInterval;
    //     minerBlockReward = _minerBlockReward;
    // }
    
    // ** The function below is for user operation
    // deposit lp token
    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfoList[_pid];
        UserInfo storage user = userInfoMap[_pid][msg.sender];
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        updatePool(_pid);
        uint256 pending = pendingReward(_pid, msg.sender);
        if(pending >= 0) {
            userRewardSender(pending, _pid, msg.sender);
        }
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.share).div(INTERVAL);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // update share of all pools
    function updateAllPools() public {
        uint256 length = poolInfoList.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // withdraw lpToken form Deposit pool
    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfoList[_pid];
        UserInfo storage user = userInfoMap[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: amount not enough");
        updatePool(_pid);
        uint256 pending = pendingReward(_pid, msg.sender);
        if(pending > 0) {
            userRewardSender(pending, _pid, msg.sender);
        }
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.share).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // withdraw reward form Deposit pool
    function withdrawReward(uint256 _pid) external {
        PoolInfo storage pool = poolInfoList[_pid];
        UserInfo storage user = userInfoMap[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = pendingReward(_pid, msg.sender);
        require(pending >= 0, "withdrawReward: reward pool empty");
        userRewardSender(pending, _pid, msg.sender);
        user.rewardDebt = user.amount.mul(pool.share).div(1e12);
    }
    
    // ** The function below is for display parameters
    // the length of deposit pool
    function poolLength() external view returns (uint256) {
        return poolInfoList.length;
    }

    // show the pending reward
    function pendingReward(uint256 _pid, address _user) public view returns (uint256) {
        if(block.number < startBlock) return 0;
        PoolInfo storage pool = poolInfoList[_pid];
        UserInfo storage user = userInfoMap[_pid][_user];
        // uint256 blockInterval = block.number.sub(user.depositBlock);
        // if (user.depositBlock == 0 || user.depositBlock > block.number) {
        uint256 blockInterval = testBlockNum.sub(pool.lastRewardBlock);
        if(pool.lpToken.balanceOf(address(this)) == 0) {
            return 0;
        }
        if (pool.lastRewardBlock == 0 || pool.lastRewardBlock > testBlockNum) {
            return 0;
        }
        uint256 share = pool.share.add(blockInterval.mul(minerBlockReward).mul(INTERVAL).mul(pool.weightPoint).div(totalWeightPoint).div(pool.lpToken.balanceOf(address(this))));
        uint256 pendingAmount = user.amount.mul(share).div(INTERVAL).sub(user.rewardDebt);
        pendingAmount = giftToken.balanceOf(address(this)) > pendingAmount ? pendingAmount : giftToken.balanceOf(address(this));
        pendingAmount = pendingAmount.add(getPioneerReward(_pid, _user));
        return pendingAmount;
    }
    
    
    // show the pending reward
    function ab(uint256 _pid, address _user) public view returns (uint256) {
        if(block.number < startBlock) return 0;
        PoolInfo storage pool = poolInfoList[_pid];
        UserInfo storage user = userInfoMap[_pid][_user];
        // uint256 blockInterval = block.number.sub(user.depositBlock);
        // if (user.depositBlock == 0 || user.depositBlock > block.number) {
        return testBlockNum.sub(pool.lastRewardBlock);
    }
    
    // show the pending reward
    function a(uint256 _pid, address _user) public view returns (uint256) {
        if(block.number < startBlock) return 0;
        PoolInfo storage pool = poolInfoList[_pid];
        UserInfo storage user = userInfoMap[_pid][_user];
        // uint256 blockInterval = block.number.sub(user.depositBlock);
        // if (user.depositBlock == 0 || user.depositBlock > block.number) {
        uint256 blockInterval = testBlockNum.sub(pool.lastRewardBlock);
        if(pool.lpToken.balanceOf(address(this)) == 0) {
            return 0;
        }
        if (pool.lastRewardBlock == 0 || pool.lastRewardBlock > testBlockNum) {
            return 0;
        }
        return pool.share.add(blockInterval.mul(minerBlockReward).mul(INTERVAL).mul(pool.weightPoint).div(totalWeightPoint).div(pool.lpToken.balanceOf(address(this))));
        
    }
    



    // show the pending reward
    function aa(uint256 _pid, address _user) public view returns (uint256) {
        if(block.number < startBlock) return 0;
        PoolInfo storage pool = poolInfoList[_pid];
        UserInfo storage user = userInfoMap[_pid][_user];
        // uint256 blockInterval = block.number.sub(user.depositBlock);
        // if (user.depositBlock == 0 || user.depositBlock > block.number) {
        uint256 blockInterval = testBlockNum.sub(pool.lastRewardBlock);
        if(pool.lpToken.balanceOf(address(this)) == 0) {
            return 0;
        }
        if (pool.lastRewardBlock == 0 || pool.lastRewardBlock > testBlockNum) {
            return 0;
        }
        uint256 share = pool.share.add(blockInterval.mul(minerBlockReward).mul(INTERVAL).mul(pool.weightPoint).div(totalWeightPoint).div(pool.lpToken.balanceOf(address(this))));
        return user.amount.mul(share).div(INTERVAL).sub(user.rewardDebt);
    }
    


    // ** The function below is for private function
    // send user reward
    function userRewardSender(uint256 rewardAmount, uint256 _pid, address _user) private {
        uint256 lpSupply = giftToken.balanceOf(address(this));
        if (lpSupply == 0) {
            return;
        }
        if(rewardAmount > 0) {
            giftToken.transfer(fundPool, rewardAmount.mul(9).div(10).div(10));
            giftToken.transfer(msg.sender, rewardAmount.mul(9).div(10));
            giftToken.burn(rewardAmount.div(10).div(10));
            giftToken.burn(rewardAmount.div(10));
            uint256 pioneerAmount = getPioneerReward(_pid, _user);
            if(pioneerAmount > 0) {
                pioneerInfoMap[_pid].rewardBalance = pioneerInfoMap[_pid].rewardBalance.sub(pioneerAmount); 
            }
        }
    }
    
    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfoList[_pid];
        // if (block.number <= pool.lastRewardBlock) {
        if (testBlockNum <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            // pool.lastRewardBlock = block.number;
            pool.lastRewardBlock = testBlockNum;
            return;
        }
        // uint256 winessReward = (block.number.sub(pool.lastRewardBlock)).mul(minerBlockReward).mul(pool.weightPoint).div(totalWeightPoint);
        uint256 winessReward = (testBlockNum.sub(pool.lastRewardBlock)).mul(minerBlockReward).mul(pool.weightPoint).div(totalWeightPoint);
        pool.share = pool.share.add(winessReward.mul(1e12).div(lpSupply));
        // pool.lastRewardBlock = block.number;
        pool.lastRewardBlock = testBlockNum;
        if(pioneerInfoMap[_pid].endBlock > testBlockNum && testBlockNum > pioneerInfoMap[_pid].startBlock) {
            pioneerInfoMap[_pid].endRewardDebt = pool.share;
        }
    }
    
    //get pioneer reward amount
    function getPioneerReward(uint256 _pid, address _user) public view returns (uint256) {
        PioneerInfo storage pioneer = pioneerInfoMap[_pid];
        if(pioneer.startBlock == 0) {
            return 0;
        }
        PoolInfo storage pool = poolInfoList[_pid];
        UserInfo storage user = userInfoMap[_pid][_user];
        
        uint256 startShare = user.rewardDebt > pioneer.startRewardDebt ? user.rewardDebt : pioneer.startRewardDebt;
        uint256 endShare;
        if (pool.lastRewardBlock > pioneer.endBlock) {
            endShare = pioneer.endRewardDebt;
        } else {
            uint256 blockInterval = (pioneer.endBlock > testBlockNum ? testBlockNum : pioneer.endBlock).sub(pool.lastRewardBlock);
            endShare = pool.share.add(blockInterval.mul(minerBlockReward).mul(INTERVAL).mul(pool.weightPoint).div(totalWeightPoint).div(pool.lpToken.balanceOf(address(this))));
        }
        if(startShare > endShare) return 0;
        uint256 pioneerReward = user.amount.mul(endShare.sub(startShare)).mul(pioneer.blockReward).div(minerBlockReward).div(INTERVAL);
        return pioneerReward > pioneer.rewardBalance ? pioneer.rewardBalance : pioneerReward;
    }

    // gift token transfer
    function giftTokenTransfer(address _to, uint256 _amount) internal {
        uint256 balance = giftToken.balanceOf(address(this));
        if (_amount > balance) {
            giftToken.transfer(_to, balance);
        } else {
            giftToken.transfer(_to, _amount);
        }
    }
    
    // ** The function below is for contract developer
    // add the new Deposit pool
    function add(uint256 _weightPoint, IERC20 _lpToken) external onlyOwner {
        totalWeightPoint = totalWeightPoint.add(_weightPoint);
        updateAllPools();
        poolInfoList.push(PoolInfo({
            lpToken: _lpToken,
            weightPoint: _weightPoint,
            share: 0,
            // lastRewardBlock: block.number
            lastRewardBlock: testBlockNum
        }));
    }

    // update the miner difficulty
    function updateMinerDifficulty() public onlyOwner{
        require(currentDifficulty < 6,"updateMinerDifficulty: max Difficulty");
        currentDifficulty = currentDifficulty.add(1);
        minerBlockReward = minerBlockReward.div(2);
        uint256 length = poolInfoList.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            poolInfoList[pid].share = poolInfoList[pid].share * 2;
        }
        difficultyChangeBlock = testBlockNum;
        // difficultyChangeBlock = block.number;
    }
    
    // set the pioneer reward info
    function setPioneer(uint256 _pioneerTotalReward, uint256 _pioneerBlockReward, uint256 _pioneerEndBlock, uint256 _pioneerStartBlock, uint256 _pioneerPoolId) external onlyOwner {
        require(_pioneerTotalReward >= 0, "setPioneer: total reward value error");
        require(_pioneerBlockReward > 0, "setPioneer: block reward value error");
        require(_pioneerEndBlock > 0, "setPioneer: block interval value error");
        require(_pioneerPoolId < poolInfoList.length, "setPioneer: out off index error");
    
        PioneerInfo storage pioneerInfo =  pioneerInfoMap[_pioneerPoolId]; 
        pioneerInfo.poolId = _pioneerPoolId;
        pioneerInfo.totalReward = _pioneerTotalReward;
        pioneerInfo.blockReward = _pioneerBlockReward;
        pioneerInfo.endBlock = _pioneerEndBlock;
        pioneerInfo.startBlock = _pioneerStartBlock;
        pioneerInfo.rewardBalance = _pioneerTotalReward;
        pioneerInfo.startRewardDebt = poolInfoList[_pioneerPoolId].share;
        pioneerInfo.endRewardDebt = poolInfoList[_pioneerPoolId].share;
    }
    
    // change the fund pool address
    function changeFundPoolAddress(address _fundPool) public {
        require(msg.sender == fundPool, "dev: Insufficient permissions?");
        fundPool = _fundPool;
    }
    
    // update weightPoint of deposit pool
    function set(uint256 _pid, uint256 _weightPoint) public onlyOwner {
        updateAllPools();
        totalWeightPoint = totalWeightPoint.sub(poolInfoList[_pid].weightPoint).add(_weightPoint);
        poolInfoList[_pid].weightPoint = _weightPoint;
    }

    // set the migrator contract address.
    function setMigrator(IMigratorToken _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // migrate the lp token to a new lp token contract
    function migrate(uint256 _pid) public onlyOwner {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfoList[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }
    
}


interface IMigratorToken {
    function migrate(IERC20 token) external returns (IERC20);
}