<?php
require "conexion.php";

$id = $_GET['id'];

$stmt = $conn->prepare("SELECT KG FROM tblRollos WHERE idRollo=?");
$stmt->execute([$id]);

$d = $stmt->fetch(PDO::FETCH_ASSOC);

echo json_encode(["kg"=>$d['KG'] ?? 0]);