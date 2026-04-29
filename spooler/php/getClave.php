<?php
require "conexion.php";

$id = $_GET['id'];

$stmt = $conn->prepare("SELECT pesoBase, ancho FROM tblClaves WHERE id=?");
$stmt->execute([$id]);

echo json_encode($stmt->fetch(PDO::FETCH_ASSOC));