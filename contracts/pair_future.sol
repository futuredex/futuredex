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
    IERC20 private _usdt_real_sc;
    IERC20 private _usdt_sc;
    IERC20 private  _second_token_sc;
    address private _lp_pair_token_ad;
    
    mapping (address => uint256) private _future_vol_order;
    mapping (address => uint256) private _future_price_order;
    mapping (address => uint256) private _future_rate_order;
    mapping (address => uint8) private _future_type_order;
    mapping (address => uint8) private _is_liquidator;
    mapping (address => uint) private _time_order;
    
    uint256 private _sum_long_vol;
    uint256 private _sum_short_vol;
    //
    // constant
    uint8 constant LONG = 0;
    uint8 constant SHORT = 1;
    constructor ( address root_sc, address second_token_ad, address lp_pair_token_ad) {
        _usdt_sc = IERC20(address(0xd9145CCE52D386f254917e481eB44e9943F39138));
        _usdt_real_sc = IERC20(address(0x55d398326f99059fF775485246999027B3197955));
        _root_sc = root_sc;
        _lp_pair_token_ad = lp_pair_token_ad;
        _second_token_sc = IERC20(second_token_ad);
    }
    //
    modifier onlyLiquidator() {
    require(_is_liquidator[_msgSender()] == 1, "Ownable: caller is not the owner");
        _;
    }
    modifier onlyUserInFuture(address user) {
        require(_future_vol_order[user] > 0, "require the user to be in order");
        _;
    }
    //
    function getPricePair() public view returns(uint256) {
        uint256 price = _usdt_real_sc.balanceOf(_lp_pair_token_ad) / _second_token_sc.balanceOf(_lp_pair_token_ad);
        return price;
    }
    function getLimitOrder() public view returns(uint256) {
        return _usdt_real_sc.balanceOf(_lp_pair_token_ad)/2;
    }
    //
    function futureOrder(uint256 value, uint8 rate, uint8 type_order) public returns (bool) {
        require(value > 0 , " transfer amount zero");
        require(rate > 1, "future rate must be greater than 1");
        require(_usdt_sc.allowance(_msgSender(), address(this)) >= value, "transfer amount exceeds allowance" );
        require(_future_vol_order[_msgSender()] == 0, "require user to have no position");
        if(_future_vol_order[_msgSender()] == 0){
            if(type_order == LONG){
                if(_sum_long_vol + value * rate > getLimitOrder()){
                    return false;
                }
            } else if(type_order == SHORT){
                if(_sum_short_vol + value * rate > getLimitOrder()){
                    return false;
                }
            }
            _future_vol_order[_msgSender()] = value;
            _future_price_order[_msgSender()] = getPricePair();
            _future_rate_order[_msgSender()] = rate;
            _time_order[_msgSender()] = block.timestamp;
            
            _future_type_order[_msgSender()] = type_order;
            _usdt_sc.transferFrom(_msgSender(), _root_sc, value);
            return true;
        }
        return false;
        // else if(_future_vol_order[_msgSender()] > 0 && _future_type_order[_msgSender()] == LONG ){
        //     if(type_order == LONG){
        //         _future_price_order[_msgSender()] = (_future_price_order[_msgSender()]*_future_vol_order[_msgSender()] + value*getPricePair() )/(_future_vol_order[_msgSender()]+value);
        //         _future_vol_order[_msgSender()] = _future_vol_order[_msgSender()] + value;
        //          _time_order[_msgSender()] = block.timestamp;
        //     } else if (type_order == SHORT){
                
        //     }
        // } else if(_future_vol_order[_msgSender()] > 0 && _future_type_order[_msgSender()] == SHORT){
        //     if(type_order == LONG){
                
        //     } else if (type_order == SHORT){
                
        //     }
        // }
    }
    //
    function closePosition() public onlyUserInFuture(_msgSender()) {
        uint256 start_price = _future_price_order[_msgSender()];
        uint256 end_price = getPricePair();
        if(_future_type_order[_msgSender()] == LONG){
            if(start_price >= end_price){
                uint256 usdt_profit = _future_rate_order[_msgSender()] * _future_vol_order[_msgSender()] * (end_price - start_price)/start_price;
                _usdt_sc.transferFrom(_root_sc, _msgSender(), usdt_profit + _future_vol_order[_msgSender()]);
                resetFutureOrder(_msgSender());
            } else if(start_price < end_price){
                uint256 usdt_loss = _future_rate_order[_msgSender()] * _future_vol_order[_msgSender()] * (start_price - end_price)/start_price;
                _usdt_sc.transferFrom(_root_sc, _msgSender(),_future_vol_order[_msgSender()] - usdt_loss);
                resetFutureOrder(_msgSender());
            }
        } else if(_future_type_order[_msgSender()] == SHORT){
            if(start_price <= end_price){
                uint256 usdt_profit = _future_rate_order[_msgSender()] * _future_vol_order[_msgSender()] * (start_price - end_price)/start_price;
                _usdt_sc.transferFrom(_root_sc, _msgSender(), usdt_profit + _future_vol_order[_msgSender()]);
                resetFutureOrder(_msgSender());
            } else if(start_price < end_price){
                uint256 usdt_loss = _future_rate_order[_msgSender()] * _future_vol_order[_msgSender()] * (end_price - start_price)/start_price;
                _usdt_sc.transferFrom(_root_sc, _msgSender(),_future_vol_order[_msgSender()] - usdt_loss);
                resetFutureOrder(_msgSender());
            }
        }
    }
    //
    function getLiqPrice(address user) public view returns(uint256){
        if(_future_type_order[user] == LONG){
            uint256 liq_price =_future_price_order[user] - _future_price_order[user]/_future_rate_order[user];
            return liq_price;
        } else {
            uint256 liq_price =_future_price_order[user] + _future_price_order[user]/_future_rate_order[user];
            return liq_price;
        }
    }
    //
    function checkLiquidation(address user) public onlyUserInFuture(user) view returns(bool)  {
        uint256 liqPrice = getLiqPrice(user);
        if(_future_type_order[user] == LONG){
            if(getPricePair() <= liqPrice){
                return true;
            }
        } else {
            if(getPricePair() >= liqPrice){
                return true;
            }
        }
        return false;
    }
    // 
    function liquidation(address user) public onlyLiquidator {
        if(checkLiquidation(user)){
            resetFutureOrder(user);
        }
    }
    //
    function resetFutureOrder(address user) internal returns (bool){
        _future_vol_order[user] = 0;
        _future_price_order[user] = 0;
        return true;
    }
}