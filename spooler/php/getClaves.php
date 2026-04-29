<?php
require "conexion.php";

$stmt = $conn->query("SELECT id, NoClave FROM tblClaves");
echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));