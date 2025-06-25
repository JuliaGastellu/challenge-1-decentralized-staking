// SPDX-License-Identifier: MIT
pragma solidity 0.8.30; // Se actualizó la versión de Solidity para que coincida con el compilador actual.

import "hardhat/console.sol";
import "./ExampleExternalContract.sol"; // Asegúrate de que este archivo exista en el mismo directorio.

contract Staker {

    // --- Variables de Estado ---
    // Referencia al contrato externo que será llamado si se alcanza el umbral.
    ExampleExternalContract public exampleExternalContract;

    // Mapeo para rastrear cuánto ETH ha apostado cada dirección.
    mapping (address => uint256) public balances;

    // La cantidad objetivo de ETH a recolectar (1 ETH).
    uint256 public constant threshold = 1 ether;

    // Fecha límite para las apuestas (timestamp de Unix).
    uint256 public deadline;

    // Bandera para indicar si el umbral se ha cumplido y los fondos se han transferido.
    bool public completed;

    // Bandera para indicar si los usuarios pueden retirar sus fondos (si el umbral no se cumplió).
    bool public openForWithdraw;

    // --- Eventos ---
    // Evento para registrar las apuestas exitosas.
    event Stake(address indexed staker, uint256 amount);
    // Evento para registrar los retiros exitosos (se puede añadir más adelante para mejor UX/seguimiento).
    event Withdraw(address indexed staker, uint256 amount);
    // Evento para registrar cuando el contrato ejecuta (llama a 'complete' en el contrato externo).
    event Execute(uint256 totalAmount);


    // --- Constructor ---
    // El constructor se ejecuta una vez cuando el contrato es desplegado.
    // Toma la dirección de 'ExampleExternalContract' como argumento.
    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
        // Establece la fecha límite 30 segundos después del despliegue para pruebas locales.
        deadline = block.timestamp + 30 seconds;
        completed = false; // Inicializa el estado 'completed'.
        openForWithdraw = false; // Inicializa el estado 'openForWithdraw'.
    }

    // --- Función de Apuesta Principal ---
    // Permite a los usuarios enviar ETH al contrato y registra su balance.
    // La palabra clave 'payable' es esencial para recibir ETH.
    function stake() public payable {
        // Requerimientos básicos para asegurar la lógica de la máquina de estado (más se añadirán después).
        require(block.timestamp < deadline, "Staking period has ended.");
        require(!completed, "Staking already completed.");
        require(!openForWithdraw, "Staking is open for withdraw.");

        // Suma el ETH recibido (msg.value) al balance del remitente (msg.sender).
        balances[msg.sender] += msg.value;

        // Emite un evento para registrar la apuesta, útil para la interfaz del usuario.
        emit Stake(msg.sender, msg.value);

        // Opcional: Registra en la consola para depuración en la terminal de `yarn chain`.
        console.log("Staked %s ETH from %s. Current contract balance: %s ETH", msg.value, msg.sender, address(this).balance);
    }

    // --- Funciones de Máquina de Estado / Temporización (marcadores de posición para Checkpoint 2) ---

    // Función para ejecutar el resultado de la apuesta después de la fecha límite.
    // Puede ser llamada por cualquiera, pero solo una vez y después de la fecha límite.
    function execute() public {
    require(block.timestamp >= deadline, "Deadline has not been reached yet.");
    require(!completed, "Execution already completed."); // Evita múltiples ejecuciones

    if (address(this).balance >= threshold) {
        exampleExternalContract.complete{value: address(this).balance}();
        completed = true;
        emit Execute(address(this).balance); // Asegúrate que este evento esté declarado y emitido.
        console.log("Staking successfully executed! Funds sent to external contract.");
    } else {
        openForWithdraw = true;
        console.log("Threshold not met. Opening for withdrawals.");
    }
}

    // Permite a los usuarios retirar su ETH apostado si el umbral no se cumplió.
    function withdraw() public {
    require(openForWithdraw, "Withdrawal is not allowed at this time.");
    require(balances[msg.sender] > 0, "You have no balance to withdraw.");

    uint256 amountToWithdraw = balances[msg.sender];
    balances[msg.sender] = 0; // Importante: resetear el balance ANTES de enviar para prevenir re-entrancy.

    (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
    require(success, "Failed to withdraw ETH.");

    emit Withdraw(msg.sender, amountToWithdraw); // Asegúrate que este evento esté declarado y emitido.
    console.log("Withdrew %s ETH to %s.", amountToWithdraw, msg.sender);
}

    // Devuelve el tiempo restante hasta la fecha límite.
    function timeLeft() public view returns (uint256) {
    if (block.timestamp >= deadline) {
        return 0; // Si la fecha límite ya pasó, retorna 0.
    }
    return deadline - block.timestamp; // Si no, retorna la diferencia.
}

    // --- Función 'receive' (marcador de posición para Checkpoint 3) ---
    // Función especial que se llama cuando se envía ETH directamente al contrato
    // sin especificar una función. Luego llama a la función stake().
    receive() external payable {
        stake(); // Llama a la función 'stake' para registrar el balance.
    }
}