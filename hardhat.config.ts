import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const { ETH_SEPOILA_URL, PRIVATE_KEY = "" } = process.env;
console.log('ETH_SEPOILA_URL: ', ETH_SEPOILA_URL);
const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/fc1cbf1c7a7d4008bd62374caa7c8c54",
      accounts: ["ebeb57ed08183e021a2d457edfcc543389bd0b7a28c48fe95753d9d3d68c45c1"],
    },
  }
};

export default config;
