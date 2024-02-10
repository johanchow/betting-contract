import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const { ETH_SEPOILA_URL, PRIVATE_KEY = "" } = process.env;
console.log('ETH_SEPOILA_URL: ', ETH_SEPOILA_URL);
const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    sepolia: {
      url: "",
      accounts: [""],
    },
  }
};

export default config;
