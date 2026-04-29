<?php
require "conexion.php";

$clave = $_POST['clave'];

$stmt = $conn->prepare("INSERT INTO tblEnc (Clave) VALUES (?)");
$stmt->execute([$clave]);

echo json_encode(["idEnc"=>$conn->lastInsertId()]);