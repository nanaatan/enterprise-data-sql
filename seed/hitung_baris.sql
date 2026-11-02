-- Ringkasan sample data untuk laporan: jumlah baris per relasi, ukuran, dan variasi nilai.
-- Pemakaian:  psql -d research_db -f hitung_baris.sql
-- Versi CSV:  psql -d research_db --csv -f hitung_baris.sql > ringkasan_sample_data.csv

\pset footer off

\echo '=== 1. Jumlah baris dan ukuran per relasi (hitungan eksak) ==='
SELECT t.table_name AS relasi,
       (xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM %I', t.table_name), false, true, '')))[1]::text::bigint AS jumlah_baris,
       pg_size_pretty(pg_total_relation_size(quote_ident(t.table_name))) AS ukuran_total
FROM information_schema.tables t
WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
ORDER BY jumlah_baris DESC;

\echo '=== 2. Total ==='
SELECT sum((xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM %I', table_name), false, true, '')))[1]::text::bigint) AS total_baris,
       pg_size_pretty(pg_database_size(current_database())) AS ukuran_database
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

\echo '=== 3. Rentang waktu data ==='
SELECT min(tanggal_daftar) AS kunjungan_pertama, max(tanggal_daftar) AS kunjungan_terakhir,
       count(DISTINCT tanggal_daftar) AS jumlah_hari,
       round(count(*)::numeric / count(DISTINCT tanggal_daftar), 1) AS rata_kunjungan_per_hari
FROM pendaftaran;

\echo '=== 3b. Profil RS: rata-rata harian dan BOR ==='
SELECT
  round(count(*) FILTER (WHERE jenis_tindakan = 'Rawat_Jalan' AND extract(isodow FROM tanggal_daftar) <= 5)::numeric
        / nullif(count(DISTINCT tanggal_daftar) FILTER (WHERE extract(isodow FROM tanggal_daftar) <= 5), 0), 1) AS rawat_jalan_per_hari_kerja,
  round(count(*) FILTER (WHERE jenis_tindakan = 'IGD')::numeric / count(DISTINCT tanggal_daftar), 1) AS igd_per_hari,
  round((SELECT count(*) FROM admisi)::numeric / count(DISTINCT tanggal_daftar), 1) AS admisi_per_hari,
  (SELECT sum(r.kapasitas_ruangan) FROM ruangan r JOIN ruangan_rawat_inap ri USING (id_ruangan)) AS jumlah_tempat_tidur,
  round(100 * (SELECT sum(extract(epoch FROM waktu_keluar - waktu_masuk)) / 86400 FROM penempatan_ruangan)
        / ((SELECT sum(r.kapasitas_ruangan) FROM ruangan r JOIN ruangan_rawat_inap ri USING (id_ruangan)) * count(DISTINCT tanggal_daftar)), 1) AS bor_persen,
  round((SELECT avg(extract(epoch FROM waktu_keluar - waktu_masuk)) / 86400 FROM penempatan_ruangan)::numeric, 1) AS rata_lama_per_penempatan_hari
FROM pendaftaran;

\echo '=== 4. Kunjungan per hari dalam seminggu ==='
SELECT to_char(tanggal_daftar, 'ID') AS no_hari, trim(to_char(tanggal_daftar, 'Day')) AS hari,
       count(*) AS kunjungan, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS persen
FROM pendaftaran GROUP BY 1, 2 ORDER BY 1;

\echo '=== 5. Distribusi kolom kategorikal ==='
SELECT 'pasien.jenis_kelamin' AS kolom, jenis_kelamin AS nilai, count(*) AS jumlah,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS persen
FROM pasien GROUP BY jenis_kelamin
UNION ALL
SELECT 'pendaftaran.jenis_tindakan', jenis_tindakan, count(*), round(100.0 * count(*) / sum(count(*)) OVER (), 1)
FROM pendaftaran GROUP BY jenis_tindakan
UNION ALL
SELECT 'pendaftaran.penjamin', pj.nama_penjamin, count(*), round(100.0 * count(*) / sum(count(*)) OVER (), 1)
FROM pendaftaran pd JOIN penjamin pj USING (id_penjamin) GROUP BY pj.nama_penjamin
UNION ALL
SELECT 'pembayaran.metode_pembayaran', metode_pembayaran, count(*), round(100.0 * count(*) / sum(count(*)) OVER (), 1)
FROM pembayaran GROUP BY metode_pembayaran
UNION ALL
SELECT 'pembayaran.status_pembayaran', status_pembayaran, count(*), round(100.0 * count(*) / sum(count(*)) OVER (), 1)
FROM pembayaran GROUP BY status_pembayaran
UNION ALL
SELECT 'ruangan.status_ruangan', status_ruangan, count(*), round(100.0 * count(*) / sum(count(*)) OVER (), 1)
FROM ruangan GROUP BY status_ruangan
UNION ALL
SELECT 'kelas ruangan rawat inap', k.nama_kelas, count(*), round(100.0 * count(*) / sum(count(*)) OVER (), 1)
FROM ruangan_rawat_inap r JOIN kelas_ruangan k USING (id_kelas) GROUP BY k.nama_kelas
ORDER BY 1, 3 DESC;

\echo '=== 6. Jumlah nilai berbeda (distinct) pada kolom penting ==='
SELECT 'pasien.kota' AS kolom, count(DISTINCT kota) AS nilai_berbeda FROM pasien
UNION ALL SELECT 'pasien.tanggal_lahir_pasien', count(DISTINCT tanggal_lahir_pasien) FROM pasien
UNION ALL SELECT 'pendaftaran.nik_pasien (pasien yang pernah berkunjung)', count(DISTINCT nik_pasien) FROM pendaftaran
UNION ALL SELECT 'pendaftaran.tanggal_daftar', count(DISTINCT tanggal_daftar) FROM pendaftaran
UNION ALL SELECT 'diagnosis.kode_diagnosis', count(DISTINCT kode_diagnosis) FROM diagnosis
UNION ALL SELECT 'pelayanan_medis.id_layanan', count(DISTINCT id_layanan) FROM pelayanan_medis
UNION ALL SELECT 'pemberian_obat.no_obat', count(DISTINCT no_obat) FROM pemberian_obat
UNION ALL SELECT 'penanganan_medis.id_pegawai (dokter)', count(DISTINCT id_pegawai) FROM penanganan_medis;

\echo '=== 7. Kota pasien (10 teratas) ==='
SELECT kota, count(*) AS pasien, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS persen
FROM pasien GROUP BY kota ORDER BY pasien DESC LIMIT 10;

\echo '=== 8. Kelompok umur pasien ==='
SELECT CASE WHEN umur < 15 THEN '0-14' WHEN umur < 60 THEN '15-59' ELSE '60+' END AS kelompok_umur,
       count(*) AS pasien, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS persen
FROM (SELECT extract(year FROM age(date '2026-10-31', tanggal_lahir_pasien)) AS umur FROM pasien) x
GROUP BY 1 ORDER BY 1;

\echo '=== 9. Kemiringan kode diagnosis: 20 kode teratas ==='
SELECT kode_diagnosis, count(*) AS jumlah,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS persen,
       round(100.0 * sum(count(*)) OVER (ORDER BY count(*) DESC, kode_diagnosis) / sum(count(*)) OVER (), 1) AS persen_kumulatif
FROM diagnosis GROUP BY kode_diagnosis ORDER BY jumlah DESC LIMIT 20;

\echo '=== 10. Frekuensi kunjungan per pasien ==='
SELECT kunjungan, count(*) AS jumlah_pasien
FROM (SELECT nik_pasien, CASE WHEN count(*) >= 10 THEN '10+' ELSE lpad(count(*)::text, 2, '0') END AS kunjungan
      FROM pendaftaran GROUP BY nik_pasien) x
GROUP BY kunjungan ORDER BY kunjungan;

\echo '=== 11. Pelayanan per kunjungan ==='
SELECT round(avg(n), 2) AS rata_rata, min(n) AS minimum, max(n) AS maksimum
FROM (SELECT no_registrasi, count(*) AS n FROM pelayanan_medis GROUP BY no_registrasi) x;
