pragma solidity 0.6.12;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // for WETH
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IMasterchefDeposit.sol";
import "./interfaces/IPancakeRouter.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IWBNB.sol";

contract FarmHelper is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IMasterchefDeposit public chef;
    IPancakeRouter public router;
	IPancakeFactory public factory;
	address public wbnb;

    constructor (address _chef, address _router) public {
        chef = IMasterchefDeposit(_chef);
        router = IPancakeRouter(_router);
		factory = IPancakeFactory(router.factory());
        wbnb = router.WETH();
    }

    fallback() external payable {
        if (msg.sender != address(wbnb)) {
            revert();
        }
    }

	receive() external payable {
        if (msg.sender != address(wbnb)) {
            revert();
        }
    }

    function buyTokenWithWBNB(uint256 _wbnbAmount, address _token) internal {
        buyTokenWithWBNBPair(_wbnbAmount, _token);
    }

    function buyTokenWithWBNBPair(
        uint256 _wbnbAmount,
        address _token
    ) internal {
        address[] memory path = new address[](2);
        path[0] = wbnb;
        path[1] = _token;
        IWBNB(wbnb).approve(address(router), _wbnbAmount);
        router.swapExactTokensForTokens(
            _wbnbAmount,
            0,
            path,
            address(this),
            block.timestamp + 100
        );
    }

    function addLiquidityByTokenForPool(
        uint256 pid,
        address token0,
        address token1,
        address payable to,
		address ref
    ) public payable {
        uint256 buyAmount = msg.value.div(2);
        require(buyAmount > 0, "Insufficient BNB amount");
        IWBNB(wbnb).deposit{value: msg.value}();

        if (token0 == wbnb) {
            buyTokenWithWBNB(buyAmount, token1);
        } else if (token1 == wbnb) {
            buyTokenWithWBNB(buyAmount, token0);
        } else {
            buyTokenWithWBNB(buyAmount, token0);
            buyTokenWithWBNB(buyAmount, token1);
        }

        addLiquidity(token0, token1);

        IERC20 lp = IERC20(factory.getPair(token0, token1));
        uint256 lpAmount = lp.balanceOf(address(this));
        lp.safeApprove(address(chef), lpAmount);
        chef.depositFor(pid, to, lpAmount, ref);

		if (IWBNB(wbnb).balanceOf(address(this)) > 0) {
			IWBNB(wbnb).withdraw(IWBNB(wbnb).balanceOf(address(this)));
			to.transfer(address(this).balance);
		}
		if (token0 == wbnb) {
        	IERC20(token1).transfer(to, IERC20(token1).balanceOf(address(this)));
		} else {
        	IERC20(token0).transfer(to, IERC20(token0).balanceOf(address(this)));
		}
    }

    function addLiquidity(address token0, address token1) internal {
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));

        uint256 token1Balance = IERC20(token1).balanceOf(address(this));

        IERC20(token0).safeApprove(address(router), token0Balance);
        IERC20(token1).safeApprove(address(router), token1Balance);

        router.addLiquidity(
            token0,
            token1,
            token0Balance,
            token1Balance,
            0,
            0,
            address(this),
            block.timestamp + 100
        );
    }
}