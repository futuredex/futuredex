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
    
    mapping (address => uint256) public _future_vol_order;
    mapping (address => uint256) public _future_price_order;
    //
    mapping (address => uint256) public _open_vol_main_coin;
    mapping (address => uint256) public _open_vol_secondary_coin;
    //
    mapping (address => uint256) public _future_rate_order;
    mapping (address => uint8) public _future_type_order;
    mapping (address => bool) public _is_liquidator;
    mapping (address => uint) public _time_order;
    
    uint256 public _sum_long_vol;
    uint256 public _sum_short_vol;
    //
    // constant
    uint8 constant NO_ORDERS = 0;
    uint8 constant LONG = 1;
    uint8 constant SHORT = 2;
    // struct position
    struct Position {
        uint8 orderTye;
        uint256 vol;
        uint256 entry;
        uint256 rate;
        uint256 liqPrice;
    }
    constructor ( address root_sc, address second_token_ad, address lp_pair_token_ad) {
        _usdt_sc = IERC20(address(0x4b24bcE9e9b01e92c2F3eb7a64fc9782002c7B39));
        _usdt_real_sc = IERC20(address(0x55d398326f99059fF775485246999027B3197955));
        _root_sc = root_sc;
        _lp_pair_token_ad = lp_pair_token_ad;
        _second_token_sc = IERC20(second_token_ad);
    }
    //
    modifier onlyLiquidator() {
        require(_is_liquidator[_msgSender()] == true, "Ownable: caller is not the owner");
        _;
    }
    modifier onlyUserInFuture(address user) {
        require(_future_vol_order[user] > 0, "require the user to be in order");
        _;
    }
    modifier onlyOnwer() {
        require (_msgSender() == _onwer, "require Onwer");
        _;
    }
    //
    event OrderCreated(address userAd, uint256 vol, uint256 rate, uint256 entry, uint256 liqPrice, uint8 orderType, uint timeOrder);
    event OrderEnded(address userAd, uint256 vol, uint256 rate, uint256 entry, uint256 liqPrice, uint8 orderType, uint timeOrder);
    event Liquidation(address userAd, uint256 vol, uint256 rate, uint256 entry, uint256 liqPrice, uint8 orderType, uint timeLiquidation);
    //
    function getPricePair() public view returns(uint256, uint256) {
        // uint256 price = _usdt_real_sc.balanceOf(_lp_pair_token_ad) / _second_token_sc.balanceOf(_lp_pair_token_ad);
        return (_usdt_real_sc.balanceOf(_lp_pair_token_ad), _second_token_sc.balanceOf(_lp_pair_token_ad));
    }
    function getLimitOrder() public view returns(uint256) {
        return _usdt_real_sc.balanceOf(_lp_pair_token_ad)/2;
    }
    //
    function setLiquidator(address user, bool status) public onlyOnwer returns(bool) {
        _is_liquidator[user] = status;
        return status;
    }
    //
    function futureOrder(uint256 value, uint8 rate, uint8 type_order) public returns (bool) {
        require(value > 0 , " transfer amount zero");
        require(rate > 1, "future rate must be greater than 1");
        require(_usdt_sc.allowance(_msgSender(), address(this)) >= value, "transfer amount exceeds allowance" );
        require(_future_vol_order[_msgSender()] == 0, "require user to have no position");
        if(_future_type_order[_msgSender()] == NO_ORDERS){
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
            // _future_price_order[_msgSender()] = getPricePair();
            //
            (_open_vol_main_coin[_msgSender()], _open_vol_secondary_coin[_msgSender()]) = getPricePair(); 
            //
            _future_rate_order[_msgSender()] = rate;
            _time_order[_msgSender()] = block.timestamp;
            
            _future_type_order[_msgSender()] = type_order;
            _usdt_sc.transferFrom(_msgSender(), _root_sc, value);
            emit OrderCreated(_msgSender(), value, rate, _future_price_order[_msgSender()], getLiqPrice(_msgSender()), type_order, _time_order[_msgSender()]);
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
    function compareWithOpen(address user, uint256 end_vol_main_coin,uint256 end_vol_secondary_coin) internal view returns (bool) {
        uint256 num_1 = end_vol_main_coin * _open_vol_secondary_coin[user];
        uint256 num_2 = end_vol_secondary_coin * _open_vol_main_coin[user];
        if(num_1 >= num_2){
            return true;
        }
        return false;
    }
    function getThousandthWithOpen(address user,uint256 end_vol_main_coin, uint256 end_vol_secondary_coin) internal view returns(uint256) {
        uint256 thousand = 0;
        if(compareWithOpen(user, end_vol_main_coin, end_vol_secondary_coin)){
            thousand = 1000 * end_vol_main_coin*_open_vol_secondary_coin[_msgSender()] / ( _open_vol_main_coin[_msgSender()] * end_vol_secondary_coin ) - 1000;
            return thousand;
        }
        thousand = 1000 - 1000 * end_vol_main_coin*_open_vol_secondary_coin[_msgSender()] / ( _open_vol_main_coin[_msgSender()] * end_vol_secondary_coin );
        return thousand;
    }
    //
    function closePosition() public onlyUserInFuture(_msgSender()) returns (bool) {
        
        // check liquidation
        
        if(checkLiquidation(_msgSender())){
            resetFutureOrder(_msgSender());
            return false;
        }
        
        (uint256 end_vol_main_coin, uint256 end_vol_secondary_coin) = getPricePair();
        
        uint256 thousand = getThousandthWithOpen(_msgSender() ,end_vol_main_coin, end_vol_secondary_coin);
        
        bool compareStatus = compareWithOpen(_msgSender(), end_vol_main_coin, end_vol_secondary_coin);
        
        uint256 usdt_margin = thousand * _future_rate_order[_msgSender()] * _future_vol_order[_msgSender()] / 1000;
        
        if(_future_type_order[_msgSender()] == LONG){
            if(compareStatus){
                _usdt_sc.transferFrom(_root_sc, _msgSender(), _future_vol_order[_msgSender()] + usdt_margin);
                resetFutureOrder(_msgSender());
            } else {
                _usdt_sc.transferFrom(_root_sc, _msgSender(),_future_vol_order[_msgSender()] - usdt_margin);
                resetFutureOrder(_msgSender());
            }
        } else if(_future_type_order[_msgSender()] == SHORT){
            if(compareStatus){
                _usdt_sc.transferFrom(_root_sc, _msgSender(), _future_vol_order[_msgSender()] - usdt_margin);
                resetFutureOrder(_msgSender());
            } else {
                _usdt_sc.transferFrom(_root_sc, _msgSender(),_future_vol_order[_msgSender()] + usdt_margin);
                resetFutureOrder(_msgSender());
            }
        }
        return true;
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
        // uint256 liqPrice = getLiqPrice(user);
        (uint256 vol_main, uint256 vol_secondary) = getPricePair();
        bool compareStatus = compareWithOpen(user, vol_main, vol_secondary);
        if(_future_type_order[user] == LONG){
            if(!compareStatus){
                if(getThousandthWithOpen(user, vol_main, vol_secondary) * _future_rate_order[user] >= 1000){
                    return true;
                }
            }
        } else if(_future_type_order[user] == SHORT) {
            if(compareStatus){
                if(getThousandthWithOpen(user, vol_main, vol_secondary) * _future_rate_order[user] >= 1000){
                    return true;
                }
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
        _open_vol_main_coin[user] = 0;
        _open_vol_secondary_coin[user] = 0;
        _future_type_order[user] = NO_ORDERS;
        return true;
    }
}