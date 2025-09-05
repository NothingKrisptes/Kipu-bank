# Kipu-bank
# 🏦 Kipu Bank

**Kipu Bank** es un contrato inteligente escrito en Solidity que actúa como una bóveda minimalista para **ETH** con límites de seguridad.  
Forma parte del examen del **Módulo 2** y marca el inicio de mi portafolio Web3.

---

## 🚀 Descripción

Los usuarios pueden:

- **Depositar ETH** en su bóveda personal (`deposit()` o directamente con `receive()`).
- **Retirar ETH** hasta un máximo fijo por transacción (`WITHDRAW_CAP`).
- Los depósitos totales no pueden superar el **BANK_CAP** global configurado en el despliegue.
- Consultar su **balance personal**, el **balance global** y los contadores de depósitos y retiros.
- El **owner** puede cambiar el nombre público del banco con `renameBank()`.

El contrato sigue buenas prácticas de seguridad:
- Errores personalizados en lugar de `require` con strings.
- Patrón **Checks-Effects-Interactions** en los retiros.
- Transferencias de ETH seguras con `call`.
- Variables claras, NatSpec y modificadores.

---

## 📌 Dirección del contrato

- **Red:** Sepolia Testnet  
- **Dirección:** `[0xc370e6b596289c931e2061580f0735fb75973d4a)`  
- **Código verificado:** [Ver en Etherscan/Blockscout](https://sepolia.etherscan.io/address/0xc370e6b596289c931e2061580f0735fb75973d4a)  

---

## ⚙️ Características principales

- **Constantes & Inmutables**:
  - `VERSION`, `MIN_DEPOSIT`
  - `OWNER`, `WITHDRAW_CAP`, `BANK_CAP`
- **Storage & Mapping**:
  - `_balances`, `totalDeposited`, `depositCount`, `withdrawCount`, `bankName`
- **Eventos**:
  - `Deposited`, `Withdrawn`, `Renamed`
- **Errores personalizados**:
  - `Unauthorized`, `InsufficientAmount`, `InsufficientBalance`, `WithdrawCapExceeded`, `BankCapExceeded`, `ZeroAddress`, `InvalidCap`
- **Funciones clave**:
  - `deposit()` → **external payable**
  - `balanceOf(address)` → **external view**
  - `withdraw(uint256, address)` → respeta `WITHDRAW_CAP`
  - `_credit(...)` y `_safeTransferETH(...)` → **privadas**
  - `renameBank(string)` → solo owner

---

## 📖 Instrucciones de despliegue

### Opción A: Remix (más simple)

1. Entra en [Remix IDE](https://remix.ethereum.org/).
2. Crea la carpeta `contracts/` y pega `KipuBank.sol`.
3. Compila con **Solidity 0.8.24**.
4. En **Deploy & Run Transactions**:
   - Environment: `Injected Provider - MetaMask` (Sepolia).
   - Value = `0`.
   - Constructor params:  
     ```
     "Kipu Bank", 250000000000000000, 10000000000000000000
     ```
     (0.25 ETH de límite por retiro y 10 ETH de cap global).
5. Presiona **Deploy** y confirma en tu wallet.
6. Copia la dirección y verifica el contrato en Etherscan (Verify & Publish).

---

## 🧪 Cómo interactuar

### Depositar
- Desde Remix, pon un valor (ej: `0.01 ETH`) en **Value** y ejecuta `deposit()`.

### Consultar balance
- Ejecuta `balanceOf("<tu_address>")`.

### Retirar
- Ejecuta `withdraw(amountWei, "<destino>")`.  
  Ejemplo: `withdraw(5000000000000000, "0x123...")` (0.005 ETH).

### Cambiar nombre del banco (solo owner)
- Ejecuta `renameBank("Kipu Bank v2")`.

### Contadores
- `depositCount()` → número de depósitos.  
- `withdrawCount()` → número de retiros.  

---

## 📄 Licencia

MIT © 2025
