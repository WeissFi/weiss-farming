module 0x25929e7f29e0a30eb4e692952ba1b5b65a3a4d65ab5f2a32e1ba3edcb587f26d::math_u256 {
    public fun add_check(arg0: u256, arg1: u256) : bool {
        115792089237316195423570985008687907853269984665640564039457584007913129639935 - arg0 >= arg1
    }
    
    public fun checked_shlw(arg0: u256) : (u256, bool) {
        if (arg0 > 115792089237316195417293883273301227089434195242432897623355228563449095127040) {
            (0, true)
        } else {
            (arg0 << 64, false)
        }
    }
    
    public fun div_mod(arg0: u256, arg1: u256) : (u256, u256) {
        let v0 = arg0 / arg1;
        (v0, arg0 - v0 * arg1)
    }
    
    public fun div_round(arg0: u256, arg1: u256, arg2: bool) : u256 {
        if (arg1 == 0) {
            abort 1
        };
        let v0 = arg0 / arg1;
        if (arg2 && v0 * arg1 != arg0) {
            v0 + 1
        } else {
            v0
        }
    }
    
    public fun overflow_add(arg0: u256, arg1: u256) : u256 {
        if (!add_check(arg0, arg1)) {
            arg1 - 115792089237316195423570985008687907853269984665640564039457584007913129639935 - arg0 - 1
        } else {
            arg0 + arg1
        }
    }
    
    public fun shlw(arg0: u256) : u256 {
        arg0 << 64
    }
    
    public fun shrw(arg0: u256) : u256 {
        arg0 >> 64
    }
    
    // decompiled from Move bytecode v6
}

