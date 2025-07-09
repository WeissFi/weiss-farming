module weissfarming::publisher;
// === Imports ===
use sui::package;

// One-time init witness
public struct PUBLISHER has drop {}

fun init(otw: PUBLISHER, ctx: &mut TxContext) {
    // Claim the `Publisher` for the package!
    let publisher = package::claim(otw, ctx);
    // Return publisher & display back to you
    transfer::public_transfer(publisher, ctx.sender());
}