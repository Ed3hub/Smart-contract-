async function connect() {
    if (typeof window.ethereum !== undefined){
        await ethereum.request({ method: "eth_requestccounts"});
    }
}
async function execute() {
    // address
    // contract ABI (blueprint to interact with the contract)
    // function to be called
    // node connection (RPC URL)
}

module.exports = {
    connect,
    execute
}