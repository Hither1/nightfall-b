/**
CREDITS:

// This file is MIT Licensed.

/**
@title 
@dev Example Verifier Implementation - Bulletproof verification.
@notice Do not use this example in any production code!
*/

pragma solidity ^0.5.8;

import "./Ownable.sol"; //Ownable functions allow initializers to be re-initialised every time an upgrade happens
//import "./GM17_lib_v0.sol";
//import "./Pairing_v1.sol";
import "./Verifier_Registry_Interface.sol";

contract Bulletproof_Verifier is Ownable {

  using GM17_lib_v0 for GM17_lib_v0.Vk_GM17_v0;
  using GM17_lib_v0 for GM17_lib_v0.Proof_GM17_v0;
  using Pairing_v1 for *;

  Verifier_Registry_Interface public R; //R for 'Registry'
  GM17_lib_v0.Vk_GM17_v0 vk;

  //bytes32 priorProofId;
  //bytes32 priorVkId;
  //bool priorResult;



  constructor(address _registry) public {
      registerMe(_registry);
  }

  modifier onlyRegistry() {
    require(msg.sender == address(R));
    _;
  }

  function registerMe(address _registry) internal onlyOwner {
      R = Verifier_Registry_Interface(_registry);
      require(R.registerVerifierContract(address(this)), "Registration of this Verifier contract has failed");
  }


//DOESN'T WORK IN TRUFFLE TESTS - BUT IT SHOULD.
  function verify(uint256[] memory _proof, uint256[] memory _inputs, bytes32 _vkId) public returns (bool result) {

      bytes32 proofId;
      proofId = R.submitProof(_proof, _inputs, _vkId, address(this));

      if (verificationCalculation(_proof, _inputs, _vkId) == 0) {
          result = true;
      } else {
          result = false;
      }

      R.attestProof(proofId, _vkId, result);

      return result;
  }

  function verifyFromRegistry(uint256[] memory _proof, uint256[] memory _inputs, bytes32 _vkId) public onlyRegistry returns (bool result) {

      if (verificationCalculation(_proof, _inputs, _vkId) == 0) {
          result = true;
      } else {
          result = false;
      }

      return result;
  }

  function verificationCalculation(uint256[] memory _proof, uint256[] memory _inputs, bytes32 _vkId) public returns (uint) {

      GM17_lib_v0.Proof_GM17_v0 memory proof;
      Points.G1Point memory vk_dot_inputs;
      uint256[] memory _vk;

      vk_dot_inputs = Points.G1Point(0, 0); //initialise

      //get this vk from the registry
      _vk = R.getVk(_vkId);

      proof.A = Points.G1Point(_proof[0], _proof[1]);
      proof.B = Points.G2Point([_proof[2], _proof[3]], [_proof[4], _proof[5]]);
      proof.C = Points.G1Point(_proof[6], _proof[7]);

      vk.H = Points.G2Point([_vk[0],_vk[1]],[_vk[2],_vk[3]]);
      vk.Galpha = Points.G1Point(_vk[4],_vk[5]);
      vk.Hbeta = Points.G2Point([_vk[6],_vk[7]],[_vk[8],_vk[9]]);
      vk.Ggamma = Points.G1Point(_vk[10],_vk[11]);
      vk.Hgamma = Points.G2Point([_vk[12],_vk[13]],[_vk[14],_vk[15]]);

      vk.query.length = (_vk.length - 16)/2;
      uint j = 0;
      for (uint i = 16; i < _vk.length; i+=2) {
        vk.query[j++] = Points.G1Point(_vk[i],_vk[i+1]);
      }

      require(_inputs.length + 1 == vk.query.length, "Length of inputs[] or vk.query is incorrect!");

      for (uint i = 0; i < _inputs.length; i++)
          vk_dot_inputs = Pairing_v1.addition(vk_dot_inputs, Pairing_v1.scalar_mul(vk.query[i + 1], _inputs[i]));

      vk_dot_inputs = Pairing_v1.addition(vk_dot_inputs, vk.query[0]);

      /**
       * e(A*G^{alpha}, B*H^{beta}) = e(G^{alpha}, H^{beta}) * e(G^{psi}, H^{gamma})
       *                              * e(C, H)
       * where psi = \sum_{i=0}^l input_i pvk.query[i]
       */
      if (!Pairing_v1.pairingProd4(vk.Galpha, vk.Hbeta, vk_dot_inputs, vk.Hgamma, proof.C, vk.H, Pairing_v1.negate(Pairing_v1.addition(proof.A, vk.Galpha)), Pairing_v1.addition2(proof.B, vk.Hbeta))) {
          return 1;
      }


      /**
       * e(A, H^{gamma}) = e(G^{gamma}, B)
       */
      if (!Pairing_v1.pairingProd2(proof.A, vk.Hgamma, Pairing_v1.negate(vk.Ggamma), proof.B)) {
          return 2;
      }

      delete proof;
      delete vk_dot_inputs;
      delete _vk;
      delete vk.H;
      delete vk.Galpha;
      delete vk.Hbeta;
      delete vk.Ggamma;
      delete vk.Hgamma;
      delete vk.query;

      return 0;

  }

  function getRegistry() public view returns (address) {
      return address(R);
  }

}
