-- T5: Pembayaran (kasir)
-- Alur: tampilkan rincian tagihan kunjungan -> simpan pembayaran sebesar total tarif.
-- Metode: Non-Tunai 80% / Tunai 20%. Status: Berhasil 95% / Gagal 5%.
\set kasir random(66, 95)
\set m random(1, 100)
\set s random(1, 100)

SELECT max(no_registrasi) AS maxreg FROM pendaftaran \gset
\set reg random(greatest(1, :maxreg - 5000), :maxreg)

BEGIN;

SELECT l.nama_layanan, t.versi_harga, t.harga
FROM pelayanan_medis pm
JOIN layanan l ON l.id_layanan = pm.id_layanan
JOIN tarif t ON t.id_layanan = pm.id_layanan AND t.versi_harga = pm.versi_harga
WHERE pm.no_registrasi = :reg;

INSERT INTO pembayaran (tanggal_pembayaran, waktu_pembayaran, metode_pembayaran, status_pembayaran, id_pegawai, no_registrasi, jumlah_pembayaran)
SELECT CURRENT_DATE, LOCALTIME,
       CASE WHEN :m <= 80 THEN 'Non-Tunai' ELSE 'Tunai' END,
       CASE WHEN :s <= 95 THEN 'Berhasil' ELSE 'Gagal' END,
       :kasir, :reg, COALESCE(SUM(t.harga), 0)
FROM pelayanan_medis pm
JOIN tarif t ON t.id_layanan = pm.id_layanan AND t.versi_harga = pm.versi_harga
WHERE pm.no_registrasi = :reg;

END;
