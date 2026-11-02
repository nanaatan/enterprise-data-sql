-- T2: Buka RME pasien (dokter/perawat di poli)
-- Alur: data identitas -> alergi -> riwayat penyakit -> obat rutin
--       -> 10 diagnosis terakhir dari kunjungan sebelumnya.
-- Pasien dipilih dengan distribusi zipfian: sebagian kecil pasien (penyakit kronis) jauh lebih sering datang.
-- Jumlah pasien dibaca dari database (cepat: max pada primary key), jadi cocok untuk sf berapa pun
SELECT max(no_rm) AS n_pasien FROM rme \gset
\set rm random_zipfian(1, :n_pasien, 1.05)

SELECT p.nik_pasien, p.nama_pasien, p.tanggal_lahir_pasien, p.jenis_kelamin, r.no_rm
FROM pasien p
JOIN rme r ON r.no_rm = p.no_rm
WHERE p.no_rm = :rm;

SELECT alergi FROM alergi_rme WHERE no_rm = :rm;

SELECT riwayat_penyakit FROM riwayat_penyakit_rme WHERE no_rm = :rm;

SELECT obat_rutin FROM obat_rutin_rme WHERE no_rm = :rm;

SELECT pd.tanggal_daftar, pd.jenis_tindakan, d.kode_diagnosis, d.deskripsi_diagnosis, d.jenis_diagnosis
FROM pasien p
JOIN pendaftaran pd ON pd.nik_pasien = p.nik_pasien
JOIN pelayanan_medis pm ON pm.no_registrasi = pd.no_registrasi
JOIN diagnosis d ON d.id_pelayanan_medis = pm.id_pelayanan_medis
WHERE p.no_rm = :rm
ORDER BY pd.tanggal_daftar DESC, d.waktu_diagnosis DESC
LIMIT 10;
