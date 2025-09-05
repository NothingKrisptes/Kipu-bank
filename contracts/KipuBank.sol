// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title KipuBank — Bóveda minimalista de ETH con límites seguros
/// @author Tú
/// @notice Permite a los usuarios depositar y retirar ETH con contabilidad por cuenta,
///         respetando (1) un tope inmutable por retiro y (2) un tope global inmutable del banco.
contract KipuBank {
    // ========================= Constantes & Inmutables =========================

    /// @notice Versión del contrato
    uint256 public constant VERSION = 2;

    /// @notice Depósito mínimo aceptado por operación
    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    /// @notice Propietario/administrador del contrato
    address public immutable OWNER;

    /// @notice Tope máximo por transacción de retiro (wei)
    uint256 public immutable WITHDRAW_CAP;

    /// @notice Tope global del banco: balance máximo total permitido (wei)
    uint256 public immutable BANK_CAP;

    // ========================= Variables de almacenamiento =====================

    /// @notice Contabilidad interna de saldos por usuario
    mapping(address => uint256) private _balances;

    /// @notice Suma acumulada de depósitos aceptados (no decrece con retiros)
    uint256 public totalDeposited;

    /// @notice Número total de depósitos efectuados
    uint256 public depositCount;

    /// @notice Número total de retiros efectuados
    uint256 public withdrawCount;

    /// @notice Nombre legible del banco
    string public bankName;

    // ========================= Eventos ========================================

    /// @notice Se emite cuando un usuario deposita ETH
    /// @param account Dirección que depositó
    /// @param amount Monto depositado en wei
    /// @param newAccountBalance Balance interno del usuario tras el depósito
    /// @param newBankBalance Balance total del contrato tras el depósito
    event Deposited(
        address indexed account,
        uint256 amount,
        uint256 newAccountBalance,
        uint256 newBankBalance
    );

    /// @notice Se emite cuando un usuario retira ETH
    /// @param account Dirección que retira
    /// @param to Dirección destino que recibe el ETH
    /// @param amount Monto retirado en wei
    /// @param newAccountBalance Balance interno del usuario tras el retiro
    /// @param newBankBalance Balance total del contrato tras el retiro
    event Withdrawn(
        address indexed account,
        address indexed to,
        uint256 amount,
        uint256 newAccountBalance,
        uint256 newBankBalance
    );

    /// @notice Se emite cuando el owner cambia el nombre del banco
    event Renamed(string indexed newName);

    // ========================= Errores personalizados ==========================

    /// @notice Error genérico de autorización
    error Unauthorized();

    /// @notice Depósito insuficiente
    /// @param sent Monto enviado
    /// @param min Mínimo requerido
    error InsufficientAmount(uint256 sent, uint256 min);

    /// @notice Balance insuficiente para retirar
    /// @param requested Monto solicitado
    /// @param available Balance disponible
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice Excede el tope máximo por retiro
    /// @param requested Monto solicitado
    /// @param cap Tope por transacción
    error WithdrawCapExceeded(uint256 requested, uint256 cap);

    /// @notice Al depositar, el balance del banco superaría el BANK_CAP
    /// @param newBalance Balance total del contrato luego de incluir el depósito
    /// @param cap Tope global permitido
    error BankCapExceeded(uint256 newBalance, uint256 cap);

    /// @notice Dirección cero no válida
    error ZeroAddress();

    /// @notice Cap(s) inválidos en constructor (cero o incoherentes)
    error InvalidCap();

    // ========================= Modificador =====================================

    /// @notice Restringe acceso a OWNER
    modifier onlyOwner() {
        if (msg.sender != OWNER) revert Unauthorized();
        _;
    }

    // ========================= Constructor =====================================

    /// @param name_ Nombre legible del banco
    /// @param withdrawCapWei_ Tope de retiro por transacción en wei (> 0)
    /// @param bankCapWei_ Tope global del banco en wei (>= withdrawCapWei_ y > 0)
    constructor(
        string memory name_,
        uint256 withdrawCapWei_,
        uint256 bankCapWei_
    ) {
        if (msg.sender == address(0)) revert ZeroAddress();
        if (withdrawCapWei_ == 0 || bankCapWei_ == 0 || withdrawCapWei_ > bankCapWei_) {
            revert InvalidCap();
        }
        OWNER = msg.sender;
        bankName = name_;
        WITHDRAW_CAP = withdrawCapWei_;
        BANK_CAP = bankCapWei_;
    }

    // ========================= Funciones externas/públicas =====================

    /// @notice Deposita ETH en tu balance interno
    /// @dev external payable — valida mínimo y tope global del banco
    function deposit() external payable {
        _credit(msg.sender, msg.value);
    }

    /// @notice Recibe ETH directamente (sin calldata) aplicando mismas validaciones que deposit()
    receive() external payable {
        _credit(msg.sender, msg.value);
    }

    /// @notice Consulta el balance interno de una cuenta
    /// @param account Dirección a consultar
    /// @return Balance interno de la cuenta en wei
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @notice Balance total de ETH hospedado en el contrato
    function totalBankBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Retira `amount` a la dirección `to`, respetando el WITHDRAW_CAP
    /// @param amount Monto a retirar en wei
    /// @param to Dirección de destino que recibirá el ETH
    function withdraw(uint256 amount, address payable to) external {
        if (amount > WITHDRAW_CAP) revert WithdrawCapExceeded(amount, WITHDRAW_CAP);
        uint256 bal = _balances[msg.sender];
        if (amount > bal) revert InsufficientBalance(amount, bal);

        // Checks → Effects → Interactions
        _balances[msg.sender] = bal - amount;
        unchecked {
            ++withdrawCount; // monotónico
        }

        _safeTransferETH(to, amount);

        emit Withdrawn(msg.sender, to, amount, _balances[msg.sender], address(this).balance);
    }

    /// @notice Cambia el nombre del banco (solo owner)
    /// @param newName Nuevo nombre público
    function renameBank(string calldata newName) external onlyOwner {
        bankName = newName;
        emit Renamed(newName);
    }

    // ========================= Funciones privadas ==============================

    /// @dev Lógica común de depósito (valida mínimo y BANK_CAP), actualiza contadores y emite evento
    /// @param from Dirección a acreditar
    /// @param amount Monto enviado (msg.value)
    function _credit(address from, uint256 amount) private {
        if (amount < MIN_DEPOSIT) revert InsufficientAmount(amount, MIN_DEPOSIT);

        // En funciones payable, address(this).balance ya incluye msg.value.
        if (address(this).balance > BANK_CAP) {
            revert BankCapExceeded(address(this).balance, BANK_CAP);
        }

        _balances[from] += amount;
        unchecked {
            totalDeposited += amount;
            ++depositCount;
        }
        emit Deposited(from, amount, _balances[from], address(this).balance);
    }

    /// @dev Transferencia segura de ETH usando call con verificación
    function _safeTransferETH(address payable to, uint256 amount) private {
        if (to == address(0)) revert ZeroAddress();
        (bool ok, ) = to.call{ value: amount }("");
        require(ok, "ETH_TRANSFER_FAILED");
    }
}

