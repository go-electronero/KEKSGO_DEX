export const ETHER_ADDRESS = '0x0000000000000000000000000000000000000000'
export const GREEN = 'success'
export const RED = 'danger'
export const EXCHANGE_ADDRESS = '0xbD6D2681586719158a7491859424f2f4CA5EBf6B'
export const TOKEN_ADDRESS = '0x27bCe644d1bdd3e297e01B480d32557123F5806A'

export const DECIMALS = (10**18)

// Shortcut to avoid passing around web3 connection
export const ether = (wei) => {
  if(wei) {
    return(wei / DECIMALS) // 18 decimal places
  }
}

// Tokens and ether have same decimal resolution... p.s. (NOT ALWAYS FREN!)
// toDo fix call to token address(ca).decimals() 
export const tokens = ether
