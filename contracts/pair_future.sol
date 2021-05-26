//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;


import "./interfaces/IERC20.sol";
import "./interfaces/IERC20Metadata.sol";
import "./utils/Context.sol";
//
contract pairToken is Context {
    //
    address private _onwer;
    address private _root_sc;
    IERC20 private _usdt_sc;
    IERC20 private  _second_token_sc;
    address private _lp_pair_token_ad;
    
    mapping (address => uint256) private _future_vol_order;
    mapping (address => uint256) private _future_price_order;
    mapping (address => uint256) private _future_rate_order;
    mapping (address => uint8) private _future_type_order;
    mapping (address => uint8) private _is_liquidator;
    mapping (address => uint) private _time_order;
    //
    // constant
    uint8 constant LONG = 0;
    uint8 constant SHORT = 1;
    constructor ( address root_sc, address second_token_ad, address lp_pair_token_ad) {
        _usdt_sc = IERC20(address(0xd9145CCE52D386f254917e481eB44e9943F39138));
        _root_sc = root_sc;
        _lp_pair_token_ad = lp_pair_token_ad;
        _second_token_sc = IERC20(second_token_ad);
    }
    //
    modifier onlyLiquidator() {
    require(_is_liquidator[_msgSender()] == 1, "Ownable: caller is not the owner");
        _;
    }
    //
    function getPricePair() public view returns(uint256) {
        
    }
    //
    function futureOrder(uint256 value, uint8 rate, uint8 type_order) public {
        require(value > 0 , " transfer amount zero");
        require(rate > 1, "future rate must be greater than 1");
        require(_usdt_sc.allowance(_msgSender(), address(this)) >= value, "transfer amount exceeds allowance" );
        if(_future_vol_order[_msgSender()] == 0){
            _future_vol_order[_msgSender()] = value;
            _future_price_order[_msgSender()] = getPricePair();
            _future_type_order[_msgSender()] = type_order;
            _future_rate_order[_msgSender()] = rate;
            _time_order[_msgSender()] = block.timestamp;
        } else if(_future_vol_order[_msgSender()] > 0 && _future_type_order[_msgSender()] == LONG ){
            if(type_order == LONG){
                
            } else if (type_order == SHORT){
                
            }
        } else if(_future_vol_order[_msgSender()] > 0 && _future_type_order[_msgSender()] == SHORT){
            if(type_order == LONG){
                
            } else if (type_order == SHORT){
                
            }
        }
    }
    //
    function closePosition() public {
        
    }
    //
    function checkLiquidation(address user) public {
        
    }
    // 
    function liquidation(address user) public onlyLiquidator {
        
    }
}