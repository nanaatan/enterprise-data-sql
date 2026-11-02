-- T1: Pendaftaran pasien (petugas registrasi)
-- Alur: cari pasien berdasarkan no RM -> buat pendaftaran dengan penjamin pasien
--       -> catat sebagai Rawat Jalan (90%) atau IGD (10%) -> buat entri RME.
-- Jumlah pasien dibaca dari database (cepat: max pada primary key), jadi cocok untuk sf berapa pun
SELECT max(no_rm) AS n_pasien FROM rme \gset
\set rm random(1, :n_pasien)
\set peg random(1, 40)
\set r random(1, 100)

BEGIN;

SELECT p.nik_pasien, p.nama_pasien, p.tanggal_lahir_pasien
FROM pasien p
WHERE p.no_rm = :rm;

INSERT INTO pendaftaran (tanggal_daftar, jam_daftar, jenis_tindakan, nik_pasien, id_penjamin, id_pegawai)
SELECT CURRENT_DATE, LOCALTIME,
       CASE WHEN :r <= 90 THEN 'Rawat_Jalan' ELSE 'IGD' END,
       dp.nik_pasien, dp.id_penjamin, :peg
FROM pasien p
JOIN daftar_penjaminan dp ON dp.nik_pasien = p.nik_pasien
WHERE p.no_rm = :rm
ORDER BY dp.id_penjamin
LIMIT 1
RETURNING no_registrasi \gset

\if :r <= 90
INSERT INTO rawat_jalan (no_registrasi) VALUES (:no_registrasi);
\else
INSERT INTO igd (no_registrasi) VALUES (:no_registrasi);
\endif

INSERT INTO entri_rme (waktu_entri, isi_entri, id_pegawai)
VALUES (now(), 'Pendaftaran pasien', :peg)
RETURNING id_entri \gset

INSERT INTO entri_pendaftaran (id_entri, no_registrasi)
VALUES (:id_entri, :no_registrasi);

END;
