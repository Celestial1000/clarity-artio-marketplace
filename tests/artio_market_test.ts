import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure whitelisting works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const artist = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('artio-market', 'add-to-whitelist', [
        types.principal(artist.address)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    let checkWhitelist = chain.mineBlock([
      Tx.contractCall('artio-market', 'is-whitelisted', [
        types.principal(artist.address)
      ], deployer.address)
    ]);
    
    assertEquals(checkWhitelist.receipts[0].result.expectOk(), true);
  },
});

Clarinet.test({
  name: "Test NFT minting and listing process",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const artist = accounts.get('wallet_1')!;
    
    // First whitelist the artist
    chain.mineBlock([
      Tx.contractCall('artio-market', 'add-to-whitelist', [
        types.principal(artist.address)
      ], deployer.address)
    ]);
    
    // Mint NFT
    let mintBlock = chain.mineBlock([
      Tx.contractCall('artio-market', 'mint-artwork', [
        types.utf8("Test Art"),
        types.utf8("ipfs://test-uri")
      ], artist.address)
    ]);
    
    mintBlock.receipts[0].result.expectOk();
    const tokenId = mintBlock.receipts[0].result.expectOk();
    
    // List NFT
    let listBlock = chain.mineBlock([
      Tx.contractCall('artio-market', 'list-nft', [
        tokenId,
        types.uint(1000000), // price
        types.uint(10) // 10% royalty
      ], artist.address)
    ]);
    
    listBlock.receipts[0].result.expectOk();
    
    // Verify listing
    let checkListing = chain.mineBlock([
      Tx.contractCall('artio-market', 'get-listing', [
        tokenId
      ], deployer.address)
    ]);
    
    const listing = checkListing.receipts[0].result.expectOk();
    assertEquals(listing['price'], types.uint(1000000));
  },
});

Clarinet.test({
  name: "Test NFT purchase flow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const artist = accounts.get('wallet_1')!;
    const buyer = accounts.get('wallet_2')!;
    
    // Setup and listing (same as previous test)
    // ... [Previous setup code] ...
    
    // Purchase NFT
    let purchaseBlock = chain.mineBlock([
      Tx.contractCall('artio-market', 'purchase-nft', [
        types.uint(0) // token ID
      ], buyer.address)
    ]);
    
    purchaseBlock.receipts[0].result.expectOk();
    
    // Verify ownership transfer
    let metadataBlock = chain.mineBlock([
      Tx.contractCall('artio-market', 'get-token-metadata', [
        types.uint(0)
      ], deployer.address)
    ]);
    
    const metadata = metadataBlock.receipts[0].result.expectOk();
    assertEquals(metadata['artist'], artist.address);
  },
});