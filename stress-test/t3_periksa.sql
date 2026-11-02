-- T3: Input pemeriksaan (dokter)
-- Alur: pilih kunjungan terbaru -> buat pelayanan medis -> penanganan oleh dokter
--       -> 3 aktivitas penanganan -> 1-2 diagnosis -> entri RME.
-- Kode diagnosis sintetis bergaya ICD-10, dipilih zipfian (sedikit diagnosis sangat sering muncul).
-- Seed data harus memakai formula kode yang sama:  chr(65 + n % 26) || lpad((n / 26)::text, 2, '0')
\set dok random(121, 190)
\set dx1 random_zipfian(1, 1500, 1.1)
\set dx2 random_zipfian(1, 1500, 1.1)
\set ada_dx2 random(1, 100)

SELECT max(no_registrasi) AS maxreg FROM pendaftaran \gset
SELECT count(*) AS n_pl FROM penyediaan_layanan \gset
\set reg random(greatest(1, :maxreg - 5000), :maxreg)
\set k random(0, :n_pl - 1)

BEGIN;

INSERT INTO pelayanan_medis (waktu_mulai, waktu_selesai, no_registrasi, id_layanan, versi_harga, id_unit)
SELECT now(), now() + interval '15 minutes', :reg, pl.id_layanan,
       (SELECT max(t.versi_harga) FROM tarif t WHERE t.id_layanan = pl.id_layanan),
       pl.id_unit
FROM penyediaan_layanan pl
ORDER BY pl.id_unit, pl.id_layanan
OFFSET :k LIMIT 1
RETURNING id_pelayanan_medis \gset

INSERT INTO penanganan_medis (id_pelayanan_medis, id_pegawai, id_pegawai_peminta, id_jadwal)
VALUES (:id_pelayanan_medis, :dok, NULL, NULL);

INSERT INTO aktivitas_penanganan (id_pelayanan_medis, no_aktivitas, jenis_aktivitas, waktu_mulai, waktu_selesai, catatan_aktivitas)
VALUES
  (:id_pelayanan_medis, 1, 'Anamnesis',       now(),                        now() + interval '5 minutes',  'Keluhan utama dicatat'),
  (:id_pelayanan_medis, 2, 'Pemeriksaan Fisik', now() + interval '5 minutes',  now() + interval '10 minutes', 'Tanda vital dalam batas'),
  (:id_pelayanan_medis, 3, 'Penegakan Diagnosis', now() + interval '10 minutes', now() + interval '15 minutes', 'Rencana terapi disusun');

INSERT INTO diagnosis (kode_diagnosis, deskripsi_diagnosis, jenis_diagnosis, waktu_diagnosis, id_pelayanan_medis, no_aktivitas)
VALUES (chr(65 + :dx1 % 26) || lpad((:dx1 / 26)::text, 2, '0'),
        'Diagnosis sintetis ' || :dx1, 'Primer', now(), :id_pelayanan_medis, 3);

\if :ada_dx2 <= 50
INSERT INTO diagnosis (kode_diagnosis, deskripsi_diagnosis, jenis_diagnosis, waktu_diagnosis, id_pelayanan_medis, no_aktivitas)
VALUES (chr(65 + :dx2 % 26) || lpad((:dx2 / 26)::text, 2, '0'),
        'Diagnosis sintetis ' || :dx2, 'Sekunder', now(), :id_pelayanan_medis, 3);
\endif

INSERT INTO entri_rme (waktu_entri, isi_entri, id_pegawai)
VALUES (now(), 'Pemeriksaan dokter', :dok)
RETURNING id_entri \gset

INSERT INTO entri_pelayanan (id_entri, id_pelayanan_medis)
VALUES (:id_entri, :id_pelayanan_medis);

END;
