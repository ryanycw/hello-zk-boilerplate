pragma circom 2.1.4;

include "circomlib/comparators.circom";

template RangeProof(n) {
    assert(n <= 252);
    signal input in; // this is the number to be proved inside the range
    signal input range[2]; // the two elements should be the range, i.e. [lower bound, upper bound]
    signal output out;

    component lt = LessEqThan(n);
    component gt = GreaterEqThan(n);

    lt.in[0] <== range[0];
    lt.in[1] <== in;

    gt.in[0] <== in;
    gt.in[1] <== range[1];

    out <== lt.out * gt.out;
}

component main { public [ range ] } = RangeProof(32);

/* INPUT = {
    "in": "5",
    "range": ["1", "10"]
} */