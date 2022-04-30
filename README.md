This is test code for creating a vault with the EIP-4626 Tokenized Vault Standard that impliments an autocompounding strategy.
Be sure to do your due diligence before using any of this code. USE AT YOUR OWN RISK!

# Vault with autocompounding strategy
All Contracts used injected web-3 through remix. In order to write to the contracts, you will need to use the contract through remix.

Step 1: Go to contract adress below and copy the source code.  
Step 2: Paste source code into file on remix and compile it (make sure you are using correct version of compiler!).  
Step 3: Go to Deploy and Run Trasactions, DO NOT DEPLOY WHAT YOU COMPILED! Instead choose the enviroment to be injected web-3 and then in
the At Address paste the contract address you copied the source code from.  
Now you should see the contract you wanted to interact with under deployed contracts. You can then use the functions on remix to then interact with the contract on the Rinkeby Testnet.  

# Contract Addresses on Rinkeby Testnet:  
Apple Token: [0xBbB76769D71302a828D5a745B4e984ceFE345cBF](https://rinkeby.etherscan.io/address/0xBbB76769D71302a828D5a745B4e984ceFE345cBF) (Use Compiler Version 0.6.12)  
AppleMasterChef: [0x1AA5C230fFaCc818655503d39a14adE6F96d81D0](https://rinkeby.etherscan.io/address/0x1AA5C230fFaCc818655503d39a14adE6F96d81D0) (Use Compiler Version 0.6.12). 
Vault: [0xeEd0Cb151E7e633675eEd04996D61a3Fd0058EE6](https://rinkeby.etherscan.io/address/0xeEd0Cb151E7e633675eEd04996D61a3Fd0058EE6) (Use Compiler 0.8.0)

The vault will let you deposit your appletokens into the apple master chef to gain rewards. It then has a reinvest function that is called whenever someone deposits or withdraws. This collects all the rewarded apple tokens and then deposits them into apple master chef compunding the rewards. 

#Redeem Function not working on testnet. Had forgotten to change redeem function to also reinvest before redeeming. The corrected code is posted on github.

To test deposit/withdrawl/rewards: (Can see transaction history under this wallet [0x7b94ec20B75A4818B252bcd25A3b52c477FEb0c6](https://rinkeby.etherscan.io/address/0x7b94ec20b75a4818b252bcd25a3b52c477feb0c6)). 
