pragma circom 2.1.4;

include "https://github.com/socathie/circomlib-matrix/blob/master/circuits/matAdd.circom";
include "https://github.com/socathie/circomlib-matrix/blob/master/circuits/matElemMul.circom";
include "https://github.com/socathie/circomlib-matrix/blob/master/circuits/matElemSum.circom";
include "https://github.com/socathie/circomlib-matrix/blob/master/circuits/matElemPow.circom";
include "circomlib/poseidon.circom";
include "circomlib/comparators.circom";

//[assignment] include your RangeProof template here
template RangeProof(n) {
    assert(n <= 252);
    signal input in; // this is the number to be proved inside the range
    signal input range[2]; // the two elements should be the range, i.e. [lower bound, upper bound]
    signal output out;

    component lt = LessEqThan(n);
    component gt = GreaterEqThan(n);

    // range[1] => upper bound
    // range[0] => lower bound
    // in should be lte upper bound
    lt.in[0] <== in;
    lt.in[1] <== range[1];
    // in should be gte upper bound
    gt.in[0] <== in;
    gt.in[1] <== range[0];

    // lt.out and gt.out should be both 1
    out <== lt.out * gt.out;
}

template sudoku() {
    signal input puzzle[9][9]; // 0  where blank
    signal input solution[9][9]; // 0 where original puzzle is not blank
    signal output out;

    // check whether the solution is zero everywhere the puzzle has values (to avoid trick solution)

    component mul = matElemMul(9,9);
    
    //[assignment] hint: you will need to initialize your RangeProof components here
    component range[9][9][2];
    
    for (var i=0; i<9; i++) {
        for (var j=0; j<9; j++) {
            range[i][j][0] = RangeProof(4);
            range[i][j][0].in <== solution[i][j];
            range[i][j][0].range[0] <== 0;
            range[i][j][0].range[1] <== 9;
            range[i][j][0].out === 1;

            range[i][j][1] = RangeProof(4);
            range[i][j][1].in <== puzzle[i][j];
            range[i][j][1].range[0] <== 0;
            range[i][j][1].range[1] <== 9;
            range[i][j][1].out === 1;

            //assert(puzzle[i][j]>=0); //[assignment] change assert() to use your created RangeProof instead
            //assert(puzzle[i][j]<=9); //[assignment] change assert() to use your created RangeProof instead
            //assert(solution[i][j]>=0); //[assignment] change assert() to use your created RangeProof instead
            //assert(solution[i][j]<=9); //[assignment] change assert() to use your created RangeProof instead
            mul.a[i][j] <== puzzle[i][j];
            mul.b[i][j] <== solution[i][j];
        }
    }
    for (var i=0; i<9; i++) {
        for (var j=0; j<9; j++) {
            mul.out[i][j] === 0;
        }
    }

    // sum up the two inputs to get full solution and square the full solution

    component add = matAdd(9,9);
    
    for (var i=0; i<9; i++) {
        for (var j=0; j<9; j++) {
            add.a[i][j] <== puzzle[i][j];
            add.b[i][j] <== solution[i][j];
        }
    }

    component square = matElemPow(9,9,2);

    for (var i=0; i<9; i++) {
        for (var j=0; j<9; j++) {
            square.a[i][j] <== add.out[i][j];
        }
    }

    // check all rows and columns and blocks sum to 45 and sum of sqaures = 285

    component row[9];
    component col[9];
    component block[9];
    component rowSq[9];
    component colSq[9];
    component blockSq[9];


    for (var k=0; k<9; k++) {
        row[k] = matElemSum(1,9);
        col[k] = matElemSum(1,9);
        block[k] = matElemSum(3,3);

        rowSq[k] = matElemSum(1,9);
        colSq[k] = matElemSum(1,9);
        blockSq[k] = matElemSum(3,3);

        for (var i=0; i<9; i++) {
            row[k].a[0][i] <== add.out[k][i];
            col[k].a[0][i] <== add.out[i][k];

            rowSq[k].a[0][i] <== square.out[k][i];
            colSq[k].a[0][i] <== square.out[i][k];
        }
        var x = 3*(k%3);
        var y = 3*(k\3);
        for (var i=0; i<3; i++) {
            for (var j=0; j<3; j++) {
                block[k].a[i][j] <== add.out[x+i][y+j];
                blockSq[k].a[i][j] <== square.out[x+i][y+j];
            }
        }
        row[k].out === 45;
        col[k].out === 45;
        block[k].out === 45;

        rowSq[k].out === 285;
        colSq[k].out === 285;
        blockSq[k].out === 285;
    }

    // hash the original puzzle and emit so that the dapp can listen for puzzle solved events

    component poseidon[9];
    component hash;

    hash = Poseidon(9);
    
    for (var i=0; i<9; i++) {
        poseidon[i] = Poseidon(9);
        for (var j=0; j<9; j++) {
            poseidon[i].inputs[j] <== puzzle[i][j];
        }
        hash.inputs[i] <== poseidon[i].out;
    }

    out <== hash.out;
}

component main = sudoku();

/* INPUT = {
    "puzzle": [
        ["1", "0", "0", "0", "0", "0", "0", "0", "0"],
        ["0", "8", "0", "0", "0", "0", "0", "0", "0"],
        ["0", "0", "6", "0", "0", "0", "0", "0", "0"],
        ["0", "0", "0", "5", "0", "0", "0", "0", "0"],
        ["0", "0", "0", "0", "3", "0", "0", "0", "0"],
        ["0", "0", "0", "0", "0", "1", "0", "0", "0"],
        ["0", "0", "0", "0", "0", "0", "9", "0", "0"],
        ["0", "0", "0", "0", "0", "0", "0", "7", "0"],
        ["0", "0", "0", "0", "0", "0", "0", "0", "5"]
    ],
    "solution": [
        ["0", "7", "4", "2", "8", "5", "3", "9", "6"],
        ["2", "0", "5", "3", "9", "6", "4", "1", "7"],
        ["3", "9", "0", "4", "1", "7", "5", "2", "8"],
        ["4", "1", "7", "0", "2", "8", "6", "3", "9"],
        ["5", "2", "8", "6", "0", "9", "7", "4", "1"],
        ["6", "3", "9", "7", "4", "0", "8", "5", "2"],
        ["7", "4", "1", "8", "5", "2", "0", "6", "3"],
        ["8", "5", "2", "9", "6", "3", "1", "0", "4"],
        ["9", "6", "3", "1", "7", "4", "2", "8", "0"]
    ]
} */