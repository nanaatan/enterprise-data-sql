-- T6: Laporan manajemen (read-only, agregasi)
-- Memilih acak satu dari tiga laporan untuk periode 7 hari acak di dalam bulan data (Oktober 2026).
\set rep random(1, 3)
\set hari random(0, 24)

\if :rep = 1
-- Laporan 1: 10 diagnosis terbanyak dalam seminggu
SELECT d.kode_diagnosis, count(*) AS jumlah
FROM diagnosis d
WHERE d.waktu_diagnosis >= date '2026-10-01' + :hari
  AND d.waktu_diagnosis <  date '2026-10-01' + :hari + 7
GROUP BY d.kode_diagnosis
ORDER BY jumlah DESC
LIMIT 10;
\elif :rep = 2
-- Laporan 2: rekap kunjungan dan pembayaran per penjamin dan jenis tindakan
SELECT pj.nama_penjamin, pd.jenis_tindakan,
       count(DISTINCT pd.no_registrasi) AS kunjungan,
       sum(pb.jumlah_pembayaran) FILTER (WHERE pb.status_pembayaran = 'Berhasil') AS total_bayar
FROM pendaftaran pd
JOIN penjamin pj ON pj.id_penjamin = pd.id_penjamin
LEFT JOIN pembayaran pb ON pb.no_registrasi = pd.no_registrasi
WHERE pd.tanggal_daftar >= date '2026-10-01' + :hari
  AND pd.tanggal_daftar <  date '2026-10-01' + :hari + 7
GROUP BY pj.nama_penjamin, pd.jenis_tindakan
ORDER BY pj.nama_penjamin, pd.jenis_tindakan;
\else
-- Laporan 3: pendapatan layanan per unit
SELECT u.departemen, u.ruang_unit, count(*) AS jumlah_layanan, sum(t.harga) AS pendapatan
FROM pelayanan_medis pm
JOIN tarif t ON t.id_layanan = pm.id_layanan AND t.versi_harga = pm.versi_harga
JOIN unit_layanan u ON u.id_unit = pm.id_unit
WHERE pm.waktu_mulai >= date '2026-10-01' + :hari
  AND pm.waktu_mulai <  date '2026-10-01' + :hari + 7
GROUP BY u.departemen, u.ruang_unit
ORDER BY pendapatan DESC;
\endif
