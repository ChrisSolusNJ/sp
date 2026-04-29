<?php
require "conexion.php";

$idEnc = $_POST['idEnc'];
$accKG = $_POST['accKG'];
$accML = $_POST['accML'];
$NoBajada = $_POST['NoBajada'];
$NoBobinas = $_POST['NoBobinas'];

$conn->beginTransaction();

// acumulado
$stmt = $conn->prepare("INSERT INTO tblSpoolerUno (idEnc,accKG,accML) VALUES (?,?,?)");
$stmt->execute([$idEnc,$accKG,$accML]);

// bajada
$stmt = $conn->prepare("INSERT INTO tblSpoolerDos (idEnc,NoBajada,NoBobinas) VALUES (?,?,?)");
$stmt->execute([$idEnc,$NoBajada,$NoBobinas]);

$conn->commit();

echo json_encode(["ok"=>true]);