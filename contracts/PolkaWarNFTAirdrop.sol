pragma solidity >=0.6.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./ReentrancyGuard.sol";
import "./PolkaWarItemSystem.sol";
import "./PolkaWar.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract PolkaWarNFTAirdrop is Ownable, ReentrancyGuard, VRFConsumerBase {
    string public name = "PolkaWar: PolkaWarNFTAirdrop";

    uint256 public itemIndexCounter;
    PolkaWarItemSystem itemSystem;
    PolkaWar polkaWar;

    uint256 claimDate;
    uint256 amountToken;
    uint256 acceptCount;
    uint256 endDate;

    //list airdrop item

    mapping(uint256 => string) internal airdropItems; //id - uri

    mapping(address => uint256) internal participants; //user-tokenid
    address[] internal arrParticipants; //user-tokenid

    // add other things
    mapping(bytes32 => address) internal requestIdToSender;

    event requestedGetAirdrop(bytes32 indexed requestId);

    bytes32 internal keyHash;
    uint256 internal fee;

    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyhash,
        PolkaWarItemSystem _itemSystem,
        PolkaWar _polkaWar
    ) public VRFConsumerBase(_VRFCoordinator, _LinkToken) {
        itemIndexCounter = 0;
        keyHash = _keyhash;
        fee = 0.2 * 10**18;
        //LINK = LinkTokenInterface(_LinkToken);
        itemSystem = _itemSystem;
        polkaWar = _polkaWar;
        claimDate = 1625097600; //1 july
        amountToken = 25000000000000000000;
        acceptCount = 3000;
        endDate = 1623715200;
    }

    function changeEndDate(uint256 _endDate) public onlyOwner {
        endDate = _endDate;
    }

    function changeAcceptCount(uint256 _acceptCount) public onlyOwner {
        acceptCount = _acceptCount;
    }

    function chageClaimDate(uint256 _claimDate) public onlyOwner {
        claimDate = _claimDate;
    }

    function chageAmountToken(uint256 _amountToken) public onlyOwner {
        amountToken = _amountToken;
    }

    function initItems(string memory uriHash) public onlyOwner {
        airdropItems[++itemIndexCounter] = uriHash;
    }

    function getItemURI(uint256 index) public view returns (string memory) {
        return airdropItems[index];
    }

    function getTotalPaticipants() public view returns (uint256) {
        return arrParticipants.length;
    }

    function isJoinAirdrop(address user) public view returns (uint256) {
        return participants[user];
    }

    function claimAirdrop() public {
        require(block.timestamp > claimDate, "not on time");
        polkaWar.transfer(msg.sender, amountToken);
    }

    function getAirdrop(string memory userProvidedSeed)
        public
        returns (bytes32)
    {
        require(block.timestamp < endDate, "airdrop already finished ");
        require(
            arrParticipants.length <= acceptCount,
            "maximum 3000 participants"
        );
        require(isJoinAirdrop(msg.sender) == 0, "already joined airdrop");

        require(
            LINK.balanceOf(address(this)) > fee,
            "Not enough LINK - deposit LINK to contract first"
        );
        uint256 seed =
            uint256(
                keccak256(abi.encode(userProvidedSeed, blockhash(block.number)))
            );
        bytes32 requestId = requestRandomness(keyHash, fee, seed);
        requestIdToSender[requestId] = msg.sender;
        emit requestedGetAirdrop(requestId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber)
        internal
        override
    {
        address user = requestIdToSender[requestId];

        uint256 randomItemIndex = randomNumber % itemIndexCounter;
        string storage uriItem = airdropItems[randomItemIndex];

        uint256 tokenId = itemSystem.createItem(user, uriItem);
        participants[user] = tokenId;
        arrParticipants.push(user);
    }

    function withdrawLinkBalance() public onlyOwner {
        LINK.transfer(owner(), LINK.balanceOf(address(this)));
    }
}
