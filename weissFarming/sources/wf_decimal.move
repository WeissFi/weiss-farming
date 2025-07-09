module weissfarming::wf_decimal {
    // === Constants ===
    // 1e18
    const WAD: u256 = 1000000000000000000;
    const MIST: u256 = 1_000_000_000;
    const U64_MAX: u256 = 18446744073709551615;

    // === Public Functions ===
    public struct Decimal has copy, drop, store {
        value: u256,
    }

    public fun from(v: u64): Decimal {
        Decimal {
            value: (v as u256) * WAD,
        }
    }

    public fun from_percent(v: u8): Decimal {
        Decimal {
            value: (v as u256) * WAD / 100,
        }
    }

    public fun from_percent_u64(v: u64): Decimal {
        Decimal {
            value: (v as u256) * WAD / 100,
        }
    }

    public fun from_bps(v: u64): Decimal {
        Decimal {
            value: (v as u256) * WAD / 10_000,
        }
    }

    public fun from_scaled_val(v: u256): Decimal {
        Decimal {
            value: v,
        }
    }

    public fun to_scaled_val(v: Decimal): u256 {
        v.value
    }

    public fun to_bps(d: Decimal): u64 {
        ((d.value * 10_000) / WAD) as u64
    }

    public fun to_native_sui(d: Decimal): u64 {
        // d.value is in 18 decimals. Dividing by 1e9 (1_000_000_000) converts it to 9 decimals.
        ((d.value) / MIST) as u64
    }
 
    public fun to_native_with_decimals(d: Decimal, decimals: u8): u64 {
        let divisor = pow(from(10), (18 - decimals) as u64);
        ((d.value) / divisor.value) as u64
    }

    public fun from_native_with_decimals(value: u64, decimals: u8): Decimal {
        let multiplier = pow(from(10), (18 - decimals) as u64);
        Decimal { value: (value as u256) * multiplier.value }
    }

    public fun from_native_sui(v: u64): Decimal {
        // v is in Mist (9 decimals); to upscale to 18 decimals multiply by 1e9.
        Decimal { value: (v as u256) * MIST }
    }

    public fun add(a: Decimal, b: Decimal): Decimal {
        Decimal {
            value: a.value + b.value,
        }
    }

    public fun sub(a: Decimal, b: Decimal): Decimal {
        Decimal {
            value: a.value - b.value,
        }
    }

    public fun saturating_sub(a: Decimal, b: Decimal): Decimal {
        if (a.value < b.value) {
            Decimal { value: 0 }
        } else {
            Decimal { value: a.value - b.value }
        }
    }

    public fun mul(a: Decimal, b: Decimal): Decimal {
        Decimal {
            value: (a.value * b.value) / WAD,
        }
    }

    public fun div(a: Decimal, b: Decimal): Decimal {
        Decimal {
            value: (a.value * WAD) / b.value,
        }
    }

    public fun pow(b: Decimal, mut e: u64): Decimal {
        let mut cur_base = b;
        let mut result = from(1);

        while (e > 0) {
            if (e % 2 == 1) {
                result = mul(result, cur_base);
            };
            cur_base = mul(cur_base, cur_base);
            e = e / 2;
        };

        result
    }
    
    public fun dec_mul(a: Decimal, b: Decimal): Decimal {
        Decimal {
            // Add half WAD before dividing
            value: (a.value * b.value + (WAD / 2)) / WAD
        }
    }

    public fun dec_pow(b: Decimal, mut e: u64): Decimal {
        // 1) Cap exponent (matching Liquity's 525600000 ~ # of minutes in 1000 years)
        if (e > 525600000) {
            e = 525600000;
        };

        // 2) Standard exponentiation by squaring
        let mut cur_base = b;
        let mut result = from(1);
        while (e > 0) {
            if (e % 2 == 1) {
                result = dec_mul(result, cur_base);
            };
            cur_base = dec_mul(cur_base, cur_base);
            e = e / 2;
        };

        result
    }


    public fun floor(a: Decimal): u64 {
        ((a.value / WAD) as u64)
    }

    public fun saturating_floor(a: Decimal): u64 {
        if (a.value > U64_MAX * WAD) {
            (U64_MAX as u64)
        } else {
            floor(a)
        }
    }

    public fun ceil(a: Decimal): u64 {
        (((a.value + WAD - 1) / WAD) as u64)
    }

    public fun eq(a: Decimal, b: Decimal): bool {
        a.value == b.value
    }

    public fun ge(a: Decimal, b: Decimal): bool {
        a.value >= b.value
    }

    public fun gt(a: Decimal, b: Decimal): bool {
        a.value > b.value
    }

    public fun le(a: Decimal, b: Decimal): bool {
        a.value <= b.value
    }

    public fun lt(a: Decimal, b: Decimal): bool {
        a.value < b.value
    }

    public fun min(a: Decimal, b: Decimal): Decimal {
        if (a.value < b.value) {
            a
        } else {
            b
        }
    }

    public fun max(a: Decimal, b: Decimal): Decimal {
        if (a.value > b.value) {
            a
        } else {
            b
        }
    }
    public fun one(): Decimal {
        Decimal { value: WAD }
    }
    // Convert a Q64-scaled u128 into an 18-decimal Decimal
    public fun from_q64(v: u128): Decimal {
        // 1) Promote to 256 bits so the multiply can’t overflow 128→256:
        let v256: u256 = v as u256;
        // 2) Rescale: (v * 10^18) / 2^64
        let scaled: u256 = (v256 * WAD) / ((1 as u256) << 64);
        // 3) (Optional) defensive check you didn’t exceed your U64_MAX*WAD
        assert!(scaled <= U64_MAX * WAD, 1);
        from_scaled_val(scaled)
    }


}



// === Test Functions ===
#[test_only]
module weissfarming::decimal_tests {
    use weissfarming::wf_decimal::{
        add,
        sub,
        mul,
        div,
        floor,
        ceil,
        pow,
        lt,
        gt,
        le,
        ge,
        from,
        from_percent,
        saturating_sub,
        saturating_floor,
        from_bps,
        to_bps
    };

    #[test]
    fun test_basic() {
        let a = from(1);
        let b = from(2);
        

        assert!(add(a, b) == from(3), 0);
        assert!(sub(b, a) == from(1), 0);
        assert!(mul(a, b) == from(2), 0);
        assert!(div(b, a) == from(2), 0);
        assert!(floor(from_percent(150)) == 1, 0);
        assert!(ceil(from_percent(150)) == 2, 0);
        assert!(lt(a, b), 0);
        assert!(gt(b, a), 0);
        assert!(le(a, b), 0);
        assert!(ge(b, a), 0);
        assert!(saturating_sub(a, b) == from(0), 0);
        assert!(saturating_sub(b, a) == from(1), 0);
        assert!(saturating_floor(from(18446744073709551615)) == 18446744073709551615, 0);
        assert!(
            saturating_floor(add(from(18446744073709551615), from(1))) == 18446744073709551615,
            0,
        );
        assert!(to_bps(from_bps(50)) == 50, 0);
    }

    #[test]
    fun test_pow() {
        assert!(pow(from(5), 4) == from(625), 0);
        assert!(pow(from(3), 0) == from(1), 0);
        assert!(pow(from(3), 1) == from(3), 0);
        assert!(pow(from(3), 7) == from(2187), 0);
        assert!(pow(from(3), 8) == from(6561), 0);
    }
}