// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ICoreMetadataModule } from "@storyprotocol/core/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { IIPAccount } from "@storyprotocol/core/interfaces/IIPAccount.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";

// contracts
import { ISPGNFT } from "../../../contracts/interfaces/ISPGNFT.sol";
import { WorkflowStructs } from "../../../contracts/lib/WorkflowStructs.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract LicenseAttachmentIntegration is BaseIntegration {
    using Strings for uint256;

    ISPGNFT private spgNftContract;
    PILTerms private commUseTerms;
    uint256 private commUseTermsId;

    /// @dev To use, run the following command:
    /// forge script test/integration/workflows/LicenseAttachmentIntegration.t.sol:LicenseAttachmentIntegration \
    /// --rpc-url=$TESTNET_URL -vvvv --broadcast --priority-gas-price=1 --legacy
    function run() public override {
        super.run();
        _beginBroadcast();
        _setUpTest();
        _test_LicenseAttachmentIntegration_registerPILTermsAndAttach();
        _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms();
        _test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms();
        _endBroadcast();
    }

    function _test_LicenseAttachmentIntegration_registerPILTermsAndAttach()
        private
        logTest("test_LicenseAttachmentIntegration_registerPILTermsAndAttach")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);

        (address ipId, ) = registrationWorkflows.mintAndRegisterIp({
            spgNftContract: address(spgNftContract),
            recipient: testSender,
            ipMetadata: testIpMetadata,
            allowDuplicates: true
        });

        uint256 deadline = block.timestamp + 1000;
        (bytes memory signature, ) = _getSigForExecuteWithSig({
            ipId: ipId,
            to: licensingModuleAddr,
            deadline: deadline,
            state: IIPAccount(payable(ipId)).state(),
            data: abi.encodeWithSelector(
                ILicensingModule.attachLicenseTerms.selector,
                ipId,
                pilTemplateAddr,
                commUseTermsId
            ),
            signerSk: testSenderSk
        });

        uint256 licenseTermsId = licenseAttachmentWorkflows.registerPILTermsAndAttach({
            ipId: ipId,
            terms: commUseTerms,
            sigAttach: WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: signature })
        });

        assertEq(licenseTermsId, commUseTermsId);
    }

    function _test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms()
        private
        logTest("test_LicenseAttachmentIntegration_mintAndRegisterIpAndAttachPILTerms")
    {
        // IP 1
        {
            StoryUSD.mint(testSender, testMintFee);
            StoryUSD.approve(address(spgNftContract), testMintFee);

            (address ipId1, uint256 tokenId1, uint256 licenseTermsId1) = licenseAttachmentWorkflows
                .mintAndRegisterIpAndAttachPILTerms({
                    spgNftContract: address(spgNftContract),
                    recipient: testSender,
                    ipMetadata: testIpMetadata,
                    terms: commUseTerms,
                    allowDuplicates: true
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId1));
            assertEq(tokenId1, spgNftContract.totalSupply());
            assertEq(licenseTermsId1, pilTemplate.getLicenseTermsId(commUseTerms));
            assertEq(spgNftContract.tokenURI(tokenId1), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId1, testIpMetadata);
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsId1);
        }

        // IP 2
        {
            StoryUSD.mint(testSender, testMintFee);
            StoryUSD.approve(address(spgNftContract), testMintFee);

            (address ipId2, uint256 tokenId2, uint256 licenseTermsId2) = licenseAttachmentWorkflows
                .mintAndRegisterIpAndAttachPILTerms({
                    spgNftContract: address(spgNftContract),
                    recipient: testSender,
                    ipMetadata: testIpMetadata,
                    terms: commUseTerms,
                    allowDuplicates: true
                });
            assertTrue(ipAssetRegistry.isRegistered(ipId2));
            assertEq(tokenId2, spgNftContract.totalSupply());
            assertEq(licenseTermsId2, pilTemplate.getLicenseTermsId(commUseTerms));
            assertEq(spgNftContract.tokenURI(tokenId2), string.concat(testBaseURI, testIpMetadata.nftMetadataURI));
            assertMetadata(ipId2, testIpMetadata);
            (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
            assertEq(licenseTemplate, pilTemplateAddr);
            assertEq(licenseTermsId, licenseTermsId2);
        }
    }

    function _test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms()
        private
        logTest("test_LicenseAttachmentIntegration_registerIpAndAttachPILTerms")
    {
        StoryUSD.mint(testSender, testMintFee);
        StoryUSD.approve(address(spgNftContract), testMintFee);

        uint256 tokenId = spgNftContract.mint({
            to: testSender,
            nftMetadataURI: "",
            nftMetadataHash: bytes32(0),
            allowDuplicates: true
        });
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNftContract), tokenId);

        uint256 deadline = block.timestamp + 1000;

        (bytes memory sigMetadata, bytes32 sigAttachState) = _getSigForExecuteWithSig({
            ipId: expectedIpId,
            to: coreMetadataModuleAddr,
            deadline: deadline,
            state: bytes32(0),
            data: abi.encodeWithSelector(
                ICoreMetadataModule.setAll.selector,
                expectedIpId,
                testIpMetadata.ipMetadataURI,
                testIpMetadata.ipMetadataHash,
                testIpMetadata.nftMetadataHash
            ),
            signerSk: testSenderSk
        });

        (bytes memory sigAttach, bytes32 expectedState) = _getSigForExecuteWithSig({
            ipId: expectedIpId,
            to: licensingModuleAddr,
            deadline: deadline,
            state: sigAttachState,
            data: abi.encodeWithSelector(
                ILicensingModule.attachLicenseTerms.selector,
                expectedIpId,
                pilTemplateAddr,
                commUseTermsId
            ),
            signerSk: testSenderSk
        });

        (address ipId, uint256 licenseTermsId) = licenseAttachmentWorkflows.registerIpAndAttachPILTerms({
            nftContract: address(spgNftContract),
            tokenId: tokenId,
            ipMetadata: testIpMetadata,
            terms: commUseTerms,
            sigMetadata: WorkflowStructs.SignatureData({
                signer: testSender,
                deadline: deadline,
                signature: sigMetadata
            }),
            sigAttach: WorkflowStructs.SignatureData({ signer: testSender, deadline: deadline, signature: sigAttach })
        });

        assertEq(ipId, expectedIpId);
        assertTrue(ipAssetRegistry.isRegistered(ipId));
        assertEq(IIPAccount(payable(ipId)).state(), expectedState);
        (address expectedLicenseTemplate, uint256 expectedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms(
            expectedIpId,
            0
        );
        assertEq(expectedLicenseTemplate, pilTemplateAddr);
        assertEq(expectedLicenseTermsId, licenseTermsId);
    }

    function _setUpTest() private {
        spgNftContract = ISPGNFT(
            registrationWorkflows.createCollection(
                ISPGNFT.InitParams({
                    name: testCollectionName,
                    symbol: testCollectionSymbol,
                    baseURI: testBaseURI,
                    contractURI: testContractURI,
                    maxSupply: testMaxSupply,
                    mintFee: testMintFee,
                    mintFeeToken: testMintFeeToken,
                    mintFeeRecipient: testSender,
                    owner: testSender,
                    mintOpen: true,
                    isPublicMinting: true
                })
            )
        );

        commUseTerms = PILFlavors.commercialUse({
            mintingFee: testMintFee,
            currencyToken: testMintFeeToken,
            royaltyPolicy: royaltyPolicyLRPAddr
        });

        // TODO: this is a hack to get the license terms id, we should refactor this in the next PR
        commUseTermsId = pilTemplate.registerLicenseTerms(commUseTerms);
    }
}
