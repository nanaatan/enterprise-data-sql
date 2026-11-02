-- =====================================================================
-- Seed data sintetis: simulasi 1 bulan operasional RS tipe C (1-31 Oktober 2026)
--
-- Profil kondisi normal (lonjakan=1, V1):
--   Rawat jalan  500 kunjungan per hari kerja (Senin-Jumat, bervariasi 90-110%); Sabtu-Minggu poli tutup
--   IGD          rata-rata 40 kunjungan per hari, 24 jam, setiap hari (bervariasi 80-120%)
--   Rawat inap   35% pasien IGD + 3% pasien poli, dibatasi kapasitas tempat tidur
--   Tempat tidur 40 kamar rawat inap, 158 TT
--   Pasien       120.000 pasien terdaftar (tetap untuk V1 dan V2)
--
-- Pemakaian (dari folder yang berisi file ini dan _pelayanan.sql):
--   V1 normal         : psql -d research_db -v lonjakan=1 -f seed_data.sql
--   V2 lonjakan 3 kali: psql -d research_db -v lonjakan=3 -f seed_data.sql
--
-- Variabel:
--   lonjakan  pengali kunjungan rawat jalan dan IGD (default 1). Admisi rawat inap tetap
--             dibatasi kapasitas TT (BOR maksimum bor_maks, lama rawat rata-rata los hari).
--   bor_maks  BOR maksimum (default 1.0 = 100%)
--   los       rata-rata lama rawat per admisi dalam hari (default 4.36)
--   cek_fk    0 (default) = pemeriksaan FK dimatikan selama seeding supaya lebih cepat
--             (butuh superuser). Data tetap konsisten karena dibangkitkan dari id yang valid.
--             1 = FK diperiksa normal (dipakai untuk menguji skrip ini).
--
-- Rentang id mengikuti asumsi skrip pgbench (README pgbench):
--   pegawai 1-500: registrasi 1-40, rekam medis 41-65, kasir 66-95, admisi 96-120,
--   dokter 121-190, perawat 191-350, laboran 351-380, radiografer 381-395,
--   apoteker 396-420, koki 421-450, ahli gizi 451-470, lainnya 471-500.
-- Kode diagnosis: chr(65 + n % 26) || lpad((n / 26)::text, 2, '0'), n = 1..1500 (sama dengan T3).
-- =====================================================================

\set ON_ERROR_STOP on
\timing on

\if :{?lonjakan}
\else
  \set lonjakan 1
\endif
\if :{?bor_maks}
\else
  \set bor_maks 1.0
\endif
\if :{?los}
\else
  \set los 4.36
\endif
\if :{?cek_fk}
\else
  \set cek_fk 0
\endif

-- Pengaman: jangan menimpa database yang sudah berisi data
SELECT count(*) = 0 AS kosong FROM pegawai \gset
\if :kosong
\else
  \echo 'Tabel pegawai sudah berisi data. Seed dibatalkan (kosongkan database dulu).'
  \quit
\endif

SELECT 120000 AS np, 500 * :lonjakan AS rj_hari, 40 * :lonjakan AS igd_hari \gset
\echo '== Seed dimulai: lonjakan=' :lonjakan 'x, pasien=' :np ', rawat jalan/hari kerja=' :rj_hari ', IGD/hari=' :igd_hari

SET synchronous_commit = off;
SET work_mem = '128MB';
SET temp_buffers = '256MB';
SET maintenance_work_mem = '256MB';
\if :cek_fk
\else
  SET session_replication_role = replica;
\endif
SELECT setseed(0.2026);

-- ---------------------------------------------------------------------
-- Fungsi bantu (hanya hidup selama sesi ini)
-- h(x, salt): hash deterministik non-negatif; pick(arr, n): ambil elemen ke-(n mod panjang)
-- ---------------------------------------------------------------------
CREATE FUNCTION pg_temp.h(bigint, int) RETURNS bigint LANGUAGE sql IMMUTABLE
AS $$ SELECT (hashint8($1 * 1000003 + $2) & 2147483647)::bigint $$;

CREATE FUNCTION pg_temp.pick(text[], bigint) RETURNS text LANGUAGE sql IMMUTABLE
AS $$ SELECT $1[1 + ($2 % cardinality($1))::int] $$;

-- ---------------------------------------------------------------------
-- Daftar nilai referensi
-- ---------------------------------------------------------------------
\set nama_l '{Asep,Dedi,Ujang,Agus,Budi,Cecep,Dadang,Eko,Hendra,Iwan,Rudi,Yayan,Deden,Ade,Rizky,Fajar,Ilham,Gilang,Andi,Wahyu}'
\set nama_p '{Siti,Rina,Neneng,Euis,Dewi,Lilis,Yanti,Ratna,Nur,Ai,Dian,Fitri,Indah,Rani,Putri,Sri,Wulan,Ayu,Nia,Tuti}'
\set nama_bl '{Suryana,Hidayat,Saputra,Permana,Nugraha,Rahman,Setiawan,Gunawan,Firmansyah,Ramdani,Sulaeman,Hermawan,Kusnadi,Sopian,Maulana,Pratama,Wijaya,Santoso,Mulyana,Supriatna}'
\set kota '{"Kab. Bogor","Kab. Sukabumi","Kab. Cianjur","Kab. Bandung","Kab. Garut","Kab. Tasikmalaya","Kab. Ciamis","Kab. Kuningan","Kab. Cirebon","Kab. Majalengka","Kab. Sumedang","Kab. Indramayu","Kab. Subang","Kab. Purwakarta","Kab. Karawang","Kab. Bekasi","Kab. Bandung Barat","Kab. Pangandaran","Kota Bogor","Kota Sukabumi","Kota Bandung","Kota Cirebon","Kota Bekasi","Kota Depok","Kota Cimahi","Kota Tasikmalaya","Kota Banjar"}'
\set kode_kota '{3201,3202,3203,3204,3205,3206,3207,3208,3209,3210,3211,3212,3213,3214,3215,3216,3217,3218,3271,3272,3273,3274,3275,3276,3277,3278,3279}'
\set jalan '{Merdeka,Siliwangi,Pahlawan,Sudirman,"Ahmad Yani",Pelabuhan,Raya,Cibadak,Pasundan,Veteran,Kartini,Cipanas,Pajajaran,Diponegoro,"Gatot Subroto"}'
\set spesialis '{"Penyakit Dalam",Anak,"Obstetri dan Ginekologi","Bedah Umum",Neurologi,Kardiologi,Pulmonologi,Mata,THT,"Kulit dan Kelamin",Psikiatri,"Gigi dan Mulut",Ortopedi,Urologi,"Rehabilitasi Medik",Anestesiologi,Radiologi,"Patologi Klinik",Umum,Geriatri}'
\set alergi '{Penisilin,Amoksisilin,Sulfa,Aspirin,Ibuprofen,"Seafood",Kacang,Telur,Susu,Debu}'
\set riwayat '{Hipertensi,"Diabetes Melitus Tipe 2",Asma,"TB Paru","Penyakit Jantung Koroner",Stroke,"Gagal Ginjal Kronik","Hepatitis B",Dispepsia,Hiperkolesterolemia,Osteoartritis,PPOK,Anemia,Gout,Hipertiroid}'
\set obat_rutin '{Amlodipin,Metformin,Glimepirid,Captopril,Simvastatin,Salbutamol,Bisoprolol,Furosemid,Allopurinol,Omeprazol,Candesartan,Insulin}'
\set imunisasi '{BCG,"Hepatitis B",Polio,DPT-HB-Hib,Campak-Rubela,"Td/TT",Influenza,"COVID-19"}'
\set hasil '{Pulang,"Kontrol ulang",Pulang,Rujuk,Pulang,"Kontrol ulang"}'

-- =====================================================================
-- 1. PEGAWAI (500) dan subtipenya
-- =====================================================================
\echo '== Pegawai'
INSERT INTO pegawai (id_pegawai, nip, nama, surat_pengangkatan)
OVERRIDING SYSTEM VALUE
SELECT i,
       to_char(make_date(y, 1 + (pg_temp.h(i, 2) % 12)::int, 1 + (pg_temp.h(i, 3) % 28)::int), 'YYYYMMDD')
         || tmt::text || lpad((1 + pg_temp.h(i, 4) % 12)::text, 2, '0')
         || CASE WHEN pria THEN '1' ELSE '2' END
         || lpad(i::text, 3, '0'),
       CASE WHEN pria THEN pg_temp.pick(:'nama_l'::text[], pg_temp.h(i, 5))
            ELSE pg_temp.pick(:'nama_p'::text[], pg_temp.h(i, 5)) END
         || ' ' || pg_temp.pick(:'nama_bl'::text[], pg_temp.h(i, 6)),
       '813.3/' || lpad((pg_temp.h(i, 7) % 2000)::text, 4, '0') || '/BKD/' || tmt
FROM (
  SELECT i, y, least(2024, y + 22 + (pg_temp.h(i, 8) % 8)::int) AS tmt, pg_temp.h(i, 9) % 2 = 0 AS pria
  FROM (SELECT i, 1965 + (pg_temp.h(i, 1) % 33)::int AS y FROM generate_series(1, 500) i) a
) b;

INSERT INTO administrasi
SELECT i, CASE WHEN i <= 40 THEN 'Registrasi' WHEN i <= 65 THEN 'Rekam Medis'
               WHEN i <= 95 THEN 'Keuangan' ELSE 'Admisi' END
FROM generate_series(1, 120) i;
INSERT INTO peg_registrasi SELECT i, 'Loket ' || (1 + i % 8) FROM generate_series(1, 40) i;
INSERT INTO peg_rekam_medis
SELECT i, pg_temp.pick('{"PMIK","Koder ICD-10 Bersertifikat","Pelatihan RME"}'::text[], pg_temp.h(i, 10))
FROM generate_series(41, 65) i;
INSERT INTO peg_keuangan SELECT i, 'Kasir ' || (1 + i % 6) FROM generate_series(66, 95) i;
INSERT INTO peg_admisi_pelayanan
SELECT i, pg_temp.pick('{"Rawat Inap",IGD,"Rawat Jalan"}'::text[], i) FROM generate_series(96, 120) i;

INSERT INTO tenaga_medis
SELECT i, 'STR-' || lpad((3200000 + i)::text, 10, '0'),
       '503/' || lpad(i::text, 4, '0') || '/SIP/DINKES/' || (2020 + i % 6)
FROM generate_series(121, 350) i;
INSERT INTO dokter SELECT i, pg_temp.pick(:'spesialis'::text[], i - 121) FROM generate_series(121, 190) i;
INSERT INTO perawat
SELECT i, pg_temp.pick('{Ners,"D3 Keperawatan",Ners,"Ners Spesialis","D3 Keperawatan"}'::text[], pg_temp.h(i, 11))
FROM generate_series(191, 350) i;

INSERT INTO tenaga_paramedis
SELECT i, 'STRP-' || lpad((3200000 + i)::text, 10, '0'),
       CASE WHEN i <= 380 THEN 'Teknologi Laboratorium Medik' WHEN i <= 395 THEN 'Radiologi'
            WHEN i <= 420 THEN 'Kefarmasian' WHEN i <= 450 THEN 'Tata Boga' ELSE 'Gizi' END,
       CASE WHEN pg_temp.h(i, 12) % 3 = 0 THEN NULL ELSE 'Sertifikat Kompetensi ' || (2018 + i % 7) END
FROM generate_series(351, 470) i;
INSERT INTO laboran SELECT i, pg_temp.pick('{Hematologi,"Kimia Klinik",Mikrobiologi,Imunoserologi,Urinalisis}'::text[], i) FROM generate_series(351, 380) i;
INSERT INTO radiografer SELECT i, pg_temp.pick('{"Radiografi Konvensional","CT Scan",USG,Mammografi}'::text[], i) FROM generate_series(381, 395) i;
INSERT INTO apoteker SELECT i, '19' || lpad(i::text, 4, '0') || '/SIPA_32.02/' || (2020 + i % 6) FROM generate_series(396, 420) i;
INSERT INTO koki SELECT i, pg_temp.pick('{"Diet Rendah Garam","Diet Diabetes","Makanan Lunak","Makanan Cair","Makanan Biasa"}'::text[], i) FROM generate_series(421, 450) i;
INSERT INTO ahli_gizi SELECT i, pg_temp.pick('{"Gizi Klinik","Gizi Anak","Gizi Penyakit Ginjal","Gizi Diabetes"}'::text[], i) FROM generate_series(451, 470) i;

-- =====================================================================
-- 2. PENJAMIN (8)
-- =====================================================================
\echo '== Penjamin'
INSERT INTO penjamin (id_penjamin, nama_penjamin, jenis_penjamin, jalan, rt, rw, kota, provinsi)
OVERRIDING SYSTEM VALUE VALUES
 (1, 'BPJS Kesehatan',              'JKN',               'Jl. Merdeka No. 10',   '001', '002', 'Kota Bandung',  'Jawa Barat'),
 (2, 'Jamkesda Provinsi',           'Pemerintah Daerah', 'Jl. Diponegoro No. 22', '003', '001', 'Kota Bandung',  'Jawa Barat'),
 (3, 'Umum / Mandiri',              'Pribadi',           'Jl. Raya No. 1',       '001', '001', 'Kab. Sukabumi', 'Jawa Barat'),
 (4, 'Asuransi Sehat Sentosa',      'Swasta',            'Jl. Sudirman No. 5',   '002', '004', 'Kota Bandung',  'Jawa Barat'),
 (5, 'Asuransi Medika Prima',       'Swasta',            'Jl. Pajajaran No. 8',  '005', '003', 'Kota Bogor',    'Jawa Barat'),
 (6, 'Asuransi Bina Husada',        'Swasta',            'Jl. Veteran No. 12',   '004', '002', 'Kota Bekasi',   'Jawa Barat'),
 (7, 'Asuransi Karyawan Nusantara', 'Swasta',            'Jl. Ahmad Yani No. 3', '002', '006', 'Kota Depok',    'Jawa Barat'),
 (8, 'Asuransi Pelita Jaya',        'Swasta',            'Jl. Kartini No. 17',   '001', '005', 'Kota Cimahi',   'Jawa Barat');

INSERT INTO kontak_penjamin
SELECT id, k FROM (
  SELECT id, '022-' || (7000000 + id * 1371) AS k FROM generate_series(1, 8) id
  UNION ALL
  SELECT id, 'klaim' || id || '@penjamin.example' FROM generate_series(1, 8) id
) x;

-- =====================================================================
-- 3. PASIEN dan RME
-- =====================================================================
\echo '== RME dan pasien'
INSERT INTO rme (no_rm, id_pegawai) OVERRIDING SYSTEM VALUE
SELECT i, 41 + (pg_temp.h(i, 13) % 25)::int FROM generate_series(1, :np) i;

INSERT INTO pasien
SELECT pg_temp.pick(:'kode_kota'::text[], k - 1) || lpad((1 + pg_temp.h(i, 14) % 40)::text, 2, '0') || lpad(i::text, 10, '0'),
       i,
       CASE WHEN pria THEN pg_temp.pick(:'nama_l'::text[], pg_temp.h(i, 15))
            ELSE pg_temp.pick(:'nama_p'::text[], pg_temp.h(i, 15)) END
         || ' ' || pg_temp.pick(:'nama_bl'::text[], pg_temp.h(i, 16)),
       date '2026-10-31' - (umur * 365 + (pg_temp.h(i, 17) % 365)::int),
       CASE WHEN pria THEN 'L' ELSE 'P' END,
       'Jl. ' || pg_temp.pick(:'jalan'::text[], pg_temp.h(i, 18)) || ' No. ' || (1 + pg_temp.h(i, 19) % 200),
       lpad((1 + pg_temp.h(i, 20) % 15)::text, 3, '0'),
       lpad((1 + pg_temp.h(i, 21) % 12)::text, 3, '0'),
       pg_temp.pick(:'kota'::text[], k - 1),
       'Jawa Barat'
FROM (
  SELECT i,
         pg_temp.h(i, 22) % 100 < 49 AS pria,
         CASE WHEN pg_temp.h(i, 23) % 100 < 70 THEN 2 ELSE 1 + (pg_temp.h(i, 24) % 27)::int END AS k,
         CASE WHEN pg_temp.h(i, 25) % 100 < 15 THEN (pg_temp.h(i, 26) % 15)::int
              WHEN pg_temp.h(i, 25) % 100 < 70 THEN 15 + (pg_temp.h(i, 26) % 45)::int
              ELSE 60 + (pg_temp.h(i, 26) % 31)::int END AS umur
  FROM generate_series(1, :np) i
) x;

-- Penjamin utama tiap pasien: BPJS 75%, Umum 15%, Jamkesda 3%, swasta 7%
CREATE TEMP TABLE _pp AS
SELECT p.no_rm, p.nik_pasien,
       CASE WHEN u < 75 THEN 1 WHEN u < 90 THEN 3 WHEN u < 93 THEN 2
            ELSE 4 + (pg_temp.h(p.no_rm, 31) % 5)::int END AS id_penjamin
FROM (SELECT no_rm, nik_pasien, pg_temp.h(no_rm, 30) % 100 AS u FROM pasien) p;
ALTER TABLE _pp ADD PRIMARY KEY (no_rm);
ANALYZE _pp;

INSERT INTO daftar_penjaminan
SELECT nik_pasien, id_penjamin,
       CASE id_penjamin WHEN 1 THEN '000' || lpad(no_rm::text, 10, '0')
                        WHEN 3 THEN NULL
                        ELSE 'POL-' || id_penjamin || '-' || lpad(no_rm::text, 8, '0') END,
       CASE WHEN pg_temp.h(no_rm, 32) % 100 < 95 THEN 'Aktif' ELSE 'Tidak Aktif' END
FROM _pp
UNION ALL
SELECT nik_pasien, 3, NULL, 'Aktif'
FROM _pp
WHERE id_penjamin <> 3 AND pg_temp.h(no_rm, 33) % 100 < 30;

INSERT INTO no_telp_pasien
SELECT nik_pasien, pg_temp.pick('{0812,0813,0821,0822,0852,0853}'::text[], pg_temp.h(no_rm, 34))
                    || lpad((pg_temp.h(no_rm, 35) % 100000000)::text, 8, '0')
FROM _pp
UNION ALL
SELECT nik_pasien, pg_temp.pick('{0817,0818,0857,0858,0877,0878}'::text[], pg_temp.h(no_rm, 36))
                    || lpad((pg_temp.h(no_rm, 37) % 100000000)::text, 8, '0')
FROM _pp
WHERE pg_temp.h(no_rm, 38) % 2 = 0;

\echo '== Data klinis dasar RME'
INSERT INTO alergi_rme
SELECT no_rm, pg_temp.pick(:'alergi'::text[], pg_temp.h(no_rm, 40)) FROM rme WHERE pg_temp.h(no_rm, 41) % 100 < 20
UNION ALL
SELECT no_rm, pg_temp.pick(:'alergi'::text[], pg_temp.h(no_rm, 40) + 1 + pg_temp.h(no_rm, 42) % 9)
FROM rme WHERE pg_temp.h(no_rm, 41) % 100 < 20 AND pg_temp.h(no_rm, 43) % 2 = 0;

INSERT INTO riwayat_penyakit_rme
SELECT no_rm, pg_temp.pick(:'riwayat'::text[], pg_temp.h(no_rm, 44) + s * (1 + pg_temp.h(no_rm, 45) % 14))
FROM rme, generate_series(0, 1) s
WHERE pg_temp.h(no_rm, 46) % 100 < 40;

INSERT INTO obat_rutin_rme
SELECT no_rm, pg_temp.pick(:'obat_rutin'::text[], pg_temp.h(no_rm, 47) + s * (1 + pg_temp.h(no_rm, 48) % 11))
FROM rme, generate_series(0, 1) s
WHERE pg_temp.h(no_rm, 49) % 100 < 25;

INSERT INTO imunisasi_rme
SELECT no_rm, pg_temp.pick(:'imunisasi'::text[], pg_temp.h(no_rm, 50) + s)
FROM rme, generate_series(0, 2) s
WHERE pg_temp.h(no_rm, 51) % 100 < 50;

-- =====================================================================
-- 4. UNIT, LAYANAN, TARIF, RUANGAN, JADWAL, OBAT
-- =====================================================================
\echo '== Master layanan dan fasilitas'
-- Unit: 1-20 poli, 21 IGD, 22-31 rawat inap, 32-40 penunjang dan khusus
INSERT INTO unit_layanan (id_unit, ruang_unit, departemen) OVERRIDING SYSTEM VALUE
SELECT i, 'Poli ' || pg_temp.pick(:'spesialis'::text[], i - 1), 'Rawat Jalan' FROM generate_series(1, 20) i
UNION ALL SELECT 21, 'Instalasi Gawat Darurat', 'Gawat Darurat'
UNION ALL
SELECT i, 'Ruang ' || pg_temp.pick('{Melati,Mawar,Anggrek,Dahlia,Kenanga,Cempaka,Flamboyan,Teratai,Seruni,Bougenville}'::text[], i - 22), 'Rawat Inap'
FROM generate_series(22, 31) i
UNION ALL VALUES
 (32, 'Laboratorium Patologi Klinik', 'Penunjang Medis'),
 (33, 'Laboratorium Patologi Anatomi', 'Penunjang Medis'),
 (34, 'Instalasi Radiologi', 'Penunjang Medis'),
 (35, 'Farmasi Rawat Jalan', 'Farmasi'),
 (36, 'Farmasi Rawat Inap', 'Farmasi'),
 (37, 'Instalasi Gizi', 'Gizi'),
 (38, 'Instalasi Bedah Sentral', 'Bedah'),
 (39, 'ICU', 'Intensif'),
 (40, 'Unit Hemodialisa', 'Rawat Jalan');

-- Layanan: 1-150 Pemeriksaan, 151-300 Tindakan, 301-400 Laboratorium, 401-440 Radiologi,
--          441-470 Farmasi, 471-485 Gizi, 486-500 Operasi
INSERT INTO layanan (id_layanan, nama_layanan, kategori, deskripsi) OVERRIDING SYSTEM VALUE
SELECT l,
       CASE kat
         WHEN 'Pemeriksaan'  THEN pg_temp.pick('{"Konsultasi Dokter Umum","Konsultasi Dokter Spesialis","Pemeriksaan Lanjutan","Visite Dokter","Konsultasi Antar Bagian"}'::text[], l)
         WHEN 'Tindakan'     THEN pg_temp.pick('{"Perawatan Luka","Pemasangan Infus","Nebulisasi","Injeksi","Pemasangan Kateter","Hecting","EKG","Hemodialisa"}'::text[], l)
         WHEN 'Laboratorium' THEN pg_temp.pick('{"Hematologi Lengkap","Gula Darah Sewaktu",HbA1c,"Fungsi Ginjal","Fungsi Hati","Profil Lipid",Urinalisis,"Kultur Darah","Elektrolit"}'::text[], l)
         WHEN 'Radiologi'    THEN pg_temp.pick('{"Rontgen Thorax","Rontgen Ekstremitas","USG Abdomen","CT Scan Kepala","USG Obstetri"}'::text[], l)
         WHEN 'Farmasi'      THEN pg_temp.pick('{"Pelayanan Resep Rawat Jalan","Pelayanan Resep Rawat Inap","Peracikan Obat","Konseling Obat"}'::text[], l)
         WHEN 'Gizi'         THEN pg_temp.pick('{"Makan Pasien Rawat Inap","Konsultasi Gizi","Diet Khusus"}'::text[], l)
         ELSE                     pg_temp.pick('{Apendektomi,"Sectio Caesarea",Herniotomi,"Debridement","ORIF","Laparotomi"}'::text[], l)
       END || ' ' || lpad(l::text, 3, '0'),
       kat,
       'Layanan sintetis kategori ' || kat
FROM (
  SELECT l, CASE WHEN l <= 150 THEN 'Pemeriksaan' WHEN l <= 300 THEN 'Tindakan' WHEN l <= 400 THEN 'Laboratorium'
                 WHEN l <= 440 THEN 'Radiologi' WHEN l <= 470 THEN 'Farmasi' WHEN l <= 485 THEN 'Gizi'
                 ELSE 'Operasi' END AS kat
  FROM generate_series(1, 500) l
) x;

INSERT INTO tarif
SELECT l.id_layanan, (2024 + v)::text,
       round((b.lo + pg_temp.h(l.id_layanan, 60) % (b.hi - b.lo)) * (1 + 0.05 * v), -2)
FROM layanan l
JOIN (VALUES ('Pemeriksaan', 75000, 250000), ('Tindakan', 100000, 1500000), ('Laboratorium', 30000, 500000),
             ('Radiologi', 150000, 2000000), ('Farmasi', 20000, 300000), ('Gizi', 25000, 100000),
             ('Operasi', 3000000, 25000000)) b(kat, lo, hi) ON b.kat = l.kategori
CROSS JOIN generate_series(0, 2) v;

INSERT INTO penyediaan_layanan
SELECT DISTINCT u, l FROM (
  SELECT l, 1 + l % 20 AS u FROM generate_series(1, 300) l
  UNION ALL SELECT l, 1 + (l + 7) % 20 FROM generate_series(1, 150) l
  UNION ALL SELECT l, 21 FROM generate_series(1, 300) l WHERE l % 3 = 0
  UNION ALL SELECT l, 22 + l % 10 FROM generate_series(1, 300) l
  UNION ALL SELECT l, 39 FROM generate_series(151, 300) l WHERE l % 2 = 0
  UNION ALL SELECT l, 40 FROM generate_series(151, 300) l WHERE l % 10 = 0
  UNION ALL SELECT l, CASE WHEN l % 4 = 0 THEN 33 ELSE 32 END FROM generate_series(301, 400) l
  UNION ALL SELECT l, 21 FROM generate_series(301, 400) l WHERE l % 5 = 0
  UNION ALL SELECT l, 34 FROM generate_series(401, 440) l
  UNION ALL SELECT l, 35 FROM generate_series(441, 470) l
  UNION ALL SELECT l, 36 FROM generate_series(441, 470) l
  UNION ALL SELECT l, 37 FROM generate_series(471, 485) l
  UNION ALL SELECT l, 38 FROM generate_series(486, 500) l
) x(l, u);

INSERT INTO kelas_ruangan (id_kelas, nama_kelas) OVERRIDING SYSTEM VALUE
VALUES (1, 'VVIP'), (2, 'VIP'), (3, 'Kelas I'), (4, 'Kelas II'), (5, 'Kelas III');

INSERT INTO tarif_kelas
SELECT k, (2024 + v)::text, round(base * power(1.05, v), -3),
       make_date(2024 + v, 1, 1), CASE WHEN v < 2 THEN make_date(2024 + v, 12, 31) END
FROM (VALUES (1, 1500000), (2, 900000), (3, 500000), (4, 300000), (5, 150000)) t(k, base)
CROSS JOIN generate_series(0, 2) v;

-- Ruangan 1-40 rawat inap, 4 kamar per bangsal (kelas: VVIP 5%, VIP 10%, I 20%, II 25%, III 40%; ±160 TT),
-- 41-100 ruangan lain (poli, IGD, penunjang)
INSERT INTO ruangan (id_ruangan, nama_ruangan, kapasitas_ruangan, status_ruangan, id_unit) OVERRIDING SYSTEM VALUE
SELECT i, 'Kamar ' || lpad(i::text, 3, '0'),
       CASE WHEN i <= 40 THEN (ARRAY[1, 1, 2, 4, 6])[kelas] ELSE 1 + (pg_temp.h(i, 61) % 10)::int END,
       CASE WHEN pg_temp.h(i, 62) % 100 < 70 THEN 'Penuh' ELSE 'Tersedia' END,
       CASE WHEN i <= 40 THEN 22 + (i - 1) / 4
            ELSE (ARRAY[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,32,33,34,35,36,37,38,39,40])[1 + (i - 41) % 30] END
FROM (
  SELECT i, CASE WHEN (i - 1) % 20 = 0 THEN 1 WHEN (i - 1) % 20 <= 2 THEN 2 WHEN (i - 1) % 20 <= 6 THEN 3
                 WHEN (i - 1) % 20 <= 11 THEN 4 ELSE 5 END AS kelas
  FROM generate_series(1, 100) i
) x;

INSERT INTO ruangan_rawat_inap
SELECT i, CASE WHEN (i - 1) % 20 = 0 THEN 1 WHEN (i - 1) % 20 <= 2 THEN 2 WHEN (i - 1) % 20 <= 6 THEN 3
               WHEN (i - 1) % 20 <= 11 THEN 4 ELSE 5 END
FROM generate_series(1, 40) i;

-- Jadwal: tiap dokter 5 hari kerja. id = (dokter - 121) * 5 + hari (1=Senin .. 5=Jumat)
INSERT INTO jadwal_dokter (id_jadwal, hari, jam_mulai, jam_selesai, kuota, id_pegawai, id_unit) OVERRIDING SYSTEM VALUE
SELECT (d - 121) * 5 + k,
       (ARRAY['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'])[k],
       CASE WHEN d % 2 = 0 THEN time '08:00' ELSE time '13:00' END,
       CASE WHEN d % 2 = 0 THEN time '12:00' ELSE time '16:00' END,
       20 + (pg_temp.h(d * 10 + k, 63) % 21)::int,
       d, 1 + d % 20
FROM generate_series(121, 190) d, generate_series(1, 5) k;

INSERT INTO obat (no_obat, dosis_obat, produsen_obat, deskripsi_obat) OVERRIDING SYSTEM VALUE
SELECT i,
       pg_temp.pick('{"5 mg","10 mg","50 mg","100 mg","250 mg","500 mg","5 ml","10 ml"}'::text[], pg_temp.h(i, 64)),
       pg_temp.pick('{"PT Farma Sehat","PT Medika Lestari","PT Obat Nusantara","PT Husada Farma","PT Prima Medika","PT Bina Kimia"}'::text[], pg_temp.h(i, 65)),
       pg_temp.pick('{Paracetamol,Amoksisilin,Amlodipin,Metformin,Omeprazol,Cetirizine,Ibuprofen,Ranitidin,Simvastatin,Captopril,Dexamethasone,Ciprofloxacin,Salbutamol,Furosemid,Ondansetron,Ceftriaxone,Ambroxol,Loratadin,Diazepam,"Asam Mefenamat"}'::text[], i)
         || ' (sediaan ' || lpad(i::text, 4, '0') || ')'
FROM generate_series(1, 2000) i;

CREATE TEMP TABLE _pl AS
SELECT l.kategori AS cat,
       row_number() OVER (PARTITION BY l.kategori ORDER BY p.id_unit, p.id_layanan) AS rn,
       p.id_unit, p.id_layanan
FROM penyediaan_layanan p JOIN layanan l USING (id_layanan);
CREATE TEMP TABLE _plc AS SELECT cat, count(*) AS n FROM _pl GROUP BY cat;
ANALYZE _pl;
ANALYZE _plc;

-- =====================================================================
-- 5. PENDAFTARAN (kunjungan)
--    Rawat jalan hanya Senin-Jumat; IGD setiap hari.
--    Pasien dipilih condong ke no RM kecil (pasien kronis lebih sering datang).
--    Dirawat inap: 35% pasien IGD, 3% pasien rawat jalan, lalu dikecilkan secara proporsional
--    bila melebihi kapasitas TT (TT x hari x BOR maksimum / lama rawat).
-- =====================================================================
\echo '== Kunjungan'
CREATE TEMP TABLE _hari AS
SELECT tgl,
       round(:rj_hari * CASE WHEN extract(isodow FROM tgl) >= 6 THEN 0 ELSE 1 END
             * (0.9 + (pg_temp.h(d, 1) % 21) / 100.0))::int AS n_rj,
       round(:igd_hari * (0.8 + (pg_temp.h(d, 2) % 41) / 100.0))::int AS n_igd
FROM (SELECT d, date '2026-10-01' + d AS tgl FROM generate_series(0, 30) d) x;

-- Batas admisi menurut kapasitas TT; skala_inap < 1 berarti admisi dikecilkan
SELECT round(sum(n_igd) * 0.35 + sum(n_rj) * 0.03) AS admisi_potensial,
       floor((SELECT sum(r.kapasitas_ruangan) FROM ruangan r JOIN ruangan_rawat_inap ri USING (id_ruangan))
             * count(*) * :bor_maks / :los) AS admisi_maks
FROM _hari \gset
SELECT least(1.0, :admisi_maks::numeric / :admisi_potensial) AS skala_inap \gset
\echo '   admisi potensial:' :admisi_potensial ', kapasitas:' :admisi_maks ', skala:' :skala_inap

CREATE TEMP TABLE _reg AS
SELECT y.reg, y.tgl, y.rm, y.igd, y.inap,
       CASE WHEN y.igd THEN time '00:00' + (pg_temp.h(y.reg, 70) % 86400) * interval '1 second'
            ELSE time '07:00' + (power(random(), 1.6) * 18000) * interval '1 second' END AS jam,
       pp.nik_pasien AS nik, pp.id_penjamin,
       1 + (pg_temp.h(y.reg, 71) % 40)::int AS peg
FROM (
  SELECT r.reg::int AS reg, r.tgl,
         least(:np, 1 + floor(:np * power(random(), 1.5))::int) AS rm,
         r.igd,
         pg_temp.h(r.reg, 73) % 10000 < CASE WHEN r.igd THEN 3500 ELSE 300 END * :skala_inap AS inap
  FROM (SELECT row_number() OVER (ORDER BY v.tgl, v.igd, v.k) AS reg, v.tgl, v.igd
        FROM (SELECT h.tgl, false AS igd, k FROM _hari h, generate_series(1, h.n_rj) k
              UNION ALL
              SELECT h.tgl, true, k FROM _hari h, generate_series(1, h.n_igd) k) v) r
) y
JOIN _pp pp ON pp.no_rm = y.rm;
ALTER TABLE _reg ADD PRIMARY KEY (reg);
ANALYZE _reg;
SELECT count(*) AS nreg FROM _reg \gset
\echo '   kunjungan:' :nreg

INSERT INTO pendaftaran (no_registrasi, tanggal_daftar, jam_daftar, jenis_tindakan, hasil_penanganan, nik_pasien, id_penjamin, id_pegawai)
OVERRIDING SYSTEM VALUE
SELECT reg, tgl, jam, CASE WHEN igd THEN 'IGD' ELSE 'Rawat_Jalan' END,
       CASE WHEN inap THEN 'Rawat inap' ELSE pg_temp.pick(:'hasil'::text[], pg_temp.h(reg, 74)) END,
       nik, id_penjamin, peg
FROM _reg ORDER BY reg;

INSERT INTO igd SELECT reg FROM _reg WHERE igd ORDER BY reg;
INSERT INTO rawat_jalan SELECT reg FROM _reg WHERE NOT igd ORDER BY reg;

INSERT INTO entri_rme (id_entri, waktu_entri, isi_entri, id_pegawai) OVERRIDING SYSTEM VALUE
SELECT reg, tgl + jam, 'Pendaftaran ' || CASE WHEN igd THEN 'IGD' ELSE 'rawat jalan' END, peg
FROM _reg ORDER BY reg;
INSERT INTO entri_pendaftaran SELECT reg, reg FROM _reg ORDER BY reg;

INSERT INTO klaim_asuransi (laporan_rumah_sakit, rincian_klaim_asuransi, no_registrasi)
SELECT 'Resume medis kunjungan ' || reg,
       CASE WHEN id_penjamin = 1 THEN 'Klaim INA-CBG' ELSE 'Klaim fee for service' END
         || ', status ' || pg_temp.pick('{Diajukan,Disetujui,Disetujui,Disetujui,Pending}'::text[], pg_temp.h(reg, 75)),
       reg
FROM _reg WHERE id_penjamin <> 3 ORDER BY reg;

\echo '== Admisi dan penempatan ruangan'
INSERT INTO admisi (no_registrasi, jenis_upgrade, catatan_admisi, id_pegawai)
SELECT reg, CASE WHEN pg_temp.h(reg, 76) % 100 < 15 THEN 1 ELSE 0 END,
       pg_temp.pick('{"Masuk dari IGD","Masuk dari poli","Rujukan puskesmas","Masuk dari poli"}'::text[], pg_temp.h(reg, 77)),
       96 + (pg_temp.h(reg, 78) % 25)::int
FROM _reg WHERE inap ORDER BY reg;

INSERT INTO penempatan_ruangan
SELECT reg, masuk, 1 + (pg_temp.h(reg, 79) % 40)::int, masuk + lama * interval '1 day'
FROM (SELECT reg, tgl + jam + interval '1 hour' AS masuk, 1 + (pg_temp.h(reg, 80) % 7)::int AS lama
      FROM _reg WHERE inap) x
UNION ALL
SELECT reg, keluar1, 1 + (pg_temp.h(reg, 81) % 40)::int, keluar1 + (1 + pg_temp.h(reg, 82) % 3) * interval '1 day'
FROM (SELECT reg, tgl + jam + interval '1 hour' + (1 + pg_temp.h(reg, 80) % 7) * interval '1 day' AS keluar1
      FROM _reg WHERE inap AND pg_temp.h(reg, 83) % 100 < 20) y;

-- =====================================================================
-- 6. PELAYANAN MEDIS per jenis (setiap blok: buat _b, lalu \ir _pelayanan.sql)
-- =====================================================================

-- 6a. Penanganan medis: 1 per kunjungan + visite 1-4 hari untuk rawat inap
\echo '== Penanganan medis'
SELECT coalesce(max(id_pelayanan_medis), 0) AS base FROM pelayanan_medis \gset
CREATE TEMP TABLE _b AS
SELECT z.*, 121 + (pg_temp.h(z.id, 91) % 70)::int AS peg
FROM (
SELECT (:base + row_number() OVER (ORDER BY x.reg, x.s))::int AS id, x.reg, x.ts, x.rj
FROM (
  SELECT r.reg, 0 AS s, r.tgl + r.jam + interval '30 minutes' AS ts, NOT r.igd AS rj FROM _reg r
  UNION ALL
  SELECT r.reg, s, r.tgl + r.jam + s * interval '1 day' + interval '8 hours', false
  FROM _reg r CROSS JOIN LATERAL generate_series(1, 1 + (pg_temp.h(r.reg, 90) % 4)::int) s
  WHERE r.inap
) x
) z;
ANALYZE _b;
\set cat 'Pemeriksaan'
\set durasi '15 minutes'
\set isi 'Pemeriksaan dokter'
\ir _pelayanan.sql

INSERT INTO penanganan_medis (id_pelayanan_medis, id_pegawai, id_pegawai_peminta, id_jadwal)
SELECT id, peg,
       CASE WHEN pg_temp.h(id, 92) % 100 < 10 THEN 121 + ((peg - 121 + 1 + pg_temp.h(id, 93) % 69) % 70)::int END,
       CASE WHEN rj AND extract(isodow FROM ts) <= 5 THEN (peg - 121) * 5 + extract(isodow FROM ts)::int END
FROM _b ORDER BY id;

INSERT INTO aktivitas_penanganan
SELECT b.id, a.no, a.jenis, b.ts + (a.no - 1) * interval '5 minutes', b.ts + a.no * interval '5 minutes',
       pg_temp.pick(a.catatan, pg_temp.h(b.id, 94 + a.no))
FROM _b b
CROSS JOIN (VALUES
  (1, 'Anamnesis',           '{"Keluhan utama dicatat","Riwayat keluhan digali","Keluhan sejak 3 hari"}'::text[]),
  (2, 'Pemeriksaan Fisik',   '{"Tanda vital dalam batas","Tekanan darah meningkat","Suhu tubuh meningkat"}'::text[]),
  (3, 'Penegakan Diagnosis', '{"Rencana terapi disusun","Edukasi pasien diberikan","Rencana pemeriksaan penunjang"}'::text[])
) a(no, jenis, catatan)
ORDER BY b.id, a.no;

-- Kode diagnosis: n = 1..1500 dengan distribusi log condong (mirip Zipf):
-- ±20 kode teratas mencakup ±50% data, kode teratas ±15%
INSERT INTO diagnosis (kode_diagnosis, deskripsi_diagnosis, jenis_diagnosis, waktu_diagnosis, id_pelayanan_medis, no_aktivitas)
SELECT chr(65 + n % 26) || lpad((n / 26)::text, 2, '0'), 'Diagnosis sintetis ' || n, jenis,
       ts + interval '12 minutes', id, 3
FROM (
  SELECT id, ts, 'Primer' AS jenis, least(1500, floor(exp(ln(1501) * power(random(), 1.3)))::int) AS n FROM _b
  UNION ALL
  SELECT id, ts, 'Sekunder', least(1500, floor(exp(ln(1501) * power(random(), 1.3)))::int) FROM _b WHERE pg_temp.h(id, 98) % 2 = 0
) d
ORDER BY id;
DROP TABLE _b;

-- 6b. Perawatan klinis: semua pasien IGD, 40% rawat jalan, + 1-2 kali untuk rawat inap
\echo '== Perawatan klinis'
SELECT coalesce(max(id_pelayanan_medis), 0) AS base FROM pelayanan_medis \gset
CREATE TEMP TABLE _b AS
SELECT z.*, 191 + (pg_temp.h(z.id, 102) % 160)::int AS peg
FROM (
SELECT (:base + row_number() OVER (ORDER BY x.reg, x.s))::int AS id, x.reg, x.ts
FROM (
  SELECT r.reg, 0 AS s, r.tgl + r.jam + interval '45 minutes' AS ts FROM _reg r
  WHERE pg_temp.h(r.reg, 100) % 100 < CASE WHEN r.igd THEN 100 ELSE 40 END
  UNION ALL
  SELECT r.reg, s, r.tgl + r.jam + s * interval '1 day' + interval '10 hours'
  FROM _reg r CROSS JOIN LATERAL generate_series(1, CASE WHEN pg_temp.h(r.reg, 101) % 4 = 0 THEN 2 ELSE 1 END) s
  WHERE r.inap
) x
) z;
ANALYZE _b;
\set cat 'Tindakan'
\set durasi '20 minutes'
\set isi 'Tindakan keperawatan'
\ir _pelayanan.sql

INSERT INTO perawatan_klinis
SELECT id, pg_temp.pick('{"Perawatan Luka","Pemasangan Infus",Nebulisasi,Injeksi,"Observasi Tanda Vital","Pemasangan Kateter"}'::text[], pg_temp.h(id, 103)),
       pg_temp.pick('{"Tindakan berjalan lancar","Pasien kooperatif","Perlu observasi lanjutan"}'::text[], pg_temp.h(id, 104)),
       peg
FROM _b ORDER BY id;
DROP TABLE _b;

-- 6c. Operasi: 25% pasien rawat inap
\echo '== Operasi'
SELECT coalesce(max(id_pelayanan_medis), 0) AS base FROM pelayanan_medis \gset
CREATE TEMP TABLE _b AS
SELECT z.*, 121 + (pg_temp.h(z.id, 111) % 70)::int AS peg
FROM (
SELECT (:base + row_number() OVER (ORDER BY r.reg))::int AS id, r.reg,
       r.tgl + r.jam + interval '1 day' + interval '3 hours' AS ts
FROM _reg r WHERE r.inap AND pg_temp.h(r.reg, 110) % 4 = 0
) z;
ANALYZE _b;
\set cat 'Operasi'
\set durasi '2 hours'
\set isi 'Laporan operasi'
\ir _pelayanan.sql

INSERT INTO operasi
SELECT id, pg_temp.pick('{Apendektomi,"Sectio Caesarea",Herniotomi,Debridement,ORIF,Laparotomi,Kolesistektomi}'::text[], pg_temp.h(id, 112)),
       'OK ' || (1 + pg_temp.h(id, 113) % 4), ts,
       pg_temp.pick('{"Operasi berjalan lancar","Operasi lancar, perdarahan minimal","Pasien dipindah ke ICU untuk observasi"}'::text[], pg_temp.h(id, 114))
FROM _b ORDER BY id;

INSERT INTO peran_operasi
SELECT id, peg, 'Operator' FROM _b
UNION ALL SELECT id, 121 + ((peg - 121 + 23) % 70), 'Asisten' FROM _b
UNION ALL SELECT id, 121 + ((peg - 121 + 47) % 70), 'Anestesi' FROM _b
UNION ALL SELECT id, 191 + (pg_temp.h(id, 115) % 160)::int, 'Perawat Instrumen' FROM _b;
DROP TABLE _b;

-- 6d. Laboratorium: 70% pasien IGD, 35% rawat jalan, + 1-2 kali untuk rawat inap
\echo '== Laboratorium'
SELECT coalesce(max(id_pelayanan_medis), 0) AS base FROM pelayanan_medis \gset
CREATE TEMP TABLE _b AS
SELECT z.*, 351 + (pg_temp.h(z.id, 122) % 30)::int AS peg, 121 + (pg_temp.h(z.id, 123) % 70)::int AS dok
FROM (
SELECT (:base + row_number() OVER (ORDER BY x.reg, x.s))::int AS id, x.reg, x.ts
FROM (
  SELECT r.reg, 0 AS s, r.tgl + r.jam + interval '1 hour' AS ts FROM _reg r
  WHERE pg_temp.h(r.reg, 120) % 100 < CASE WHEN r.igd THEN 70 ELSE 35 END
  UNION ALL
  SELECT r.reg, s, r.tgl + r.jam + s * interval '1 day' + interval '6 hours'
  FROM _reg r CROSS JOIN LATERAL generate_series(1, CASE WHEN pg_temp.h(r.reg, 121) % 4 = 0 THEN 2 ELSE 1 END) s
  WHERE r.inap
) x
) z;
ANALYZE _b;
\set cat 'Laboratorium'
\set durasi '1 hour'
\set isi 'Hasil laboratorium'
\ir _pelayanan.sql

INSERT INTO penunjang_medis
SELECT id, 'Permintaan pemeriksaan laboratorium', ts::date,
       CASE WHEN pg_temp.h(id, 124) % 100 < 95 THEN 'Selesai' ELSE 'Diproses' END, dok, peg
FROM _b ORDER BY id;
INSERT INTO laboratorium
SELECT id, CASE WHEN pg_temp.h(id, 125) % 4 = 0 THEN 'Lab Patologi Anatomi' ELSE 'Lab Patologi Klinik' END,
       pg_temp.pick('{"Hematologi Lengkap","Gula Darah Sewaktu",HbA1c,"Fungsi Ginjal","Fungsi Hati","Profil Lipid",Urinalisis,Elektrolit}'::text[], pg_temp.h(id, 126)),
       pg_temp.pick('{"Dalam batas normal","Dalam batas normal","Di atas nilai rujukan","Di bawah nilai rujukan"}'::text[], pg_temp.h(id, 127)),
       peg
FROM _b ORDER BY id;
DROP TABLE _b;

-- 6e. Radiologi: 30% pasien IGD, 10% rawat jalan
\echo '== Radiologi'
SELECT coalesce(max(id_pelayanan_medis), 0) AS base FROM pelayanan_medis \gset
CREATE TEMP TABLE _b AS
SELECT z.*, 381 + (pg_temp.h(z.id, 131) % 15)::int AS peg, 121 + (pg_temp.h(z.id, 132) % 70)::int AS dok
FROM (
SELECT (:base + row_number() OVER (ORDER BY r.reg))::int AS id, r.reg,
       r.tgl + r.jam + interval '90 minutes' AS ts
FROM _reg r WHERE pg_temp.h(r.reg, 130) % 100 < CASE WHEN r.igd THEN 30 ELSE 10 END
) z;
ANALYZE _b;
\set cat 'Radiologi'
\set durasi '30 minutes'
\set isi 'Ekspertise radiologi'
\ir _pelayanan.sql

INSERT INTO penunjang_medis
SELECT id, 'Permintaan pemeriksaan radiologi', ts::date,
       CASE WHEN pg_temp.h(id, 133) % 100 < 95 THEN 'Selesai' ELSE 'Diproses' END, dok, peg
FROM _b ORDER BY id;
INSERT INTO radiologi
SELECT id, pg_temp.pick('{"Ruang X-Ray 1","Ruang X-Ray 2","Ruang CT Scan","Ruang USG"}'::text[], pg_temp.h(id, 134)),
       pg_temp.pick('{"Rontgen Thorax","Rontgen Ekstremitas","USG Abdomen","CT Scan Kepala","USG Obstetri"}'::text[], pg_temp.h(id, 135)),
       pg_temp.pick('{"Tidak tampak kelainan","Tidak tampak kelainan","Kesan infiltrat","Kesan fraktur","Kesan kardiomegali"}'::text[], pg_temp.h(id, 136)),
       peg
FROM _b ORDER BY id;
DROP TABLE _b;

-- 6f. Farmasi: 90% kunjungan, 3 obat per resep (rentang obat sama dengan T4)
\echo '== Farmasi'
SELECT coalesce(max(id_pelayanan_medis), 0) AS base FROM pelayanan_medis \gset
CREATE TEMP TABLE _b AS
SELECT z.*, 396 + (pg_temp.h(z.id, 141) % 25)::int AS peg, 121 + (pg_temp.h(z.id, 142) % 70)::int AS dok
FROM (
SELECT (:base + row_number() OVER (ORDER BY r.reg))::int AS id, r.reg,
       r.tgl + r.jam + interval '2 hours' AS ts
FROM _reg r WHERE pg_temp.h(r.reg, 140) % 10 < 9
) z;
ANALYZE _b;
\set cat 'Farmasi'
\set durasi '20 minutes'
\set isi 'Penyerahan obat'
\ir _pelayanan.sql

INSERT INTO penunjang_medis
SELECT id, 'Resep dokter', ts::date, 'Selesai', dok, peg FROM _b ORDER BY id;
INSERT INTO farmasi
SELECT id, 'Obat diserahkan ke pasien', peg FROM _b ORDER BY id;
INSERT INTO pemberian_obat
SELECT id, 1 + (pg_temp.h(id, 143) % 666)::int, (ARRAY[5, 10, 15, 30])[1 + (pg_temp.h(id, 146) % 4)::int] FROM _b
UNION ALL
SELECT id, 667 + (pg_temp.h(id, 144) % 667)::int, (ARRAY[5, 10, 15, 30])[1 + (pg_temp.h(id, 147) % 4)::int] FROM _b
UNION ALL
SELECT id, 1334 + (pg_temp.h(id, 145) % 667)::int, (ARRAY[5, 10, 15, 30])[1 + (pg_temp.h(id, 148) % 4)::int] FROM _b;
DROP TABLE _b;

-- 6g. Gizi: pasien rawat inap, 1-4 kali
\echo '== Gizi'
SELECT coalesce(max(id_pelayanan_medis), 0) AS base FROM pelayanan_medis \gset
CREATE TEMP TABLE _b AS
SELECT z.*, 451 + (pg_temp.h(z.id, 151) % 20)::int AS peg, 121 + (pg_temp.h(z.id, 152) % 70)::int AS dok, 421 + (pg_temp.h(z.id, 153) % 30)::int AS koki
FROM (
SELECT (:base + row_number() OVER (ORDER BY r.reg, s))::int AS id, r.reg,
       r.tgl + r.jam + s * interval '1 day' + interval '5 hours' AS ts
FROM _reg r CROSS JOIN LATERAL generate_series(1, 1 + (pg_temp.h(r.reg, 150) % 4)::int) s
WHERE r.inap
) z;
ANALYZE _b;
\set cat 'Gizi'
\set durasi '30 minutes'
\set isi 'Pelayanan gizi'
\ir _pelayanan.sql

INSERT INTO penunjang_medis
SELECT id, 'Permintaan diet pasien', ts::date, 'Selesai', dok, peg FROM _b ORDER BY id;
INSERT INTO gizi
SELECT id, pg_temp.pick('{"Dapur Utama","Dapur Diet Khusus"}'::text[], pg_temp.h(id, 154)),
       pg_temp.pick('{"Diet Biasa","Diet Rendah Garam","Diet Diabetes","Diet Lunak","Diet Cair","Diet Tinggi Kalori Tinggi Protein"}'::text[], pg_temp.h(id, 155)),
       1 + (pg_temp.h(id, 156) % 3)::int, peg, koki
FROM _b ORDER BY id;
DROP TABLE _b;

-- =====================================================================
-- 7. PEMBAYARAN: nominal = total tarif semua pelayanan dalam kunjungan
--    Non-Tunai 80%. 5% kunjungan punya satu percobaan Gagal sebelum Berhasil.
-- =====================================================================
\echo '== Pembayaran'
CREATE TEMP TABLE _tagihan AS
SELECT pm.no_registrasi AS reg, sum(t.harga) AS total
FROM pelayanan_medis pm
JOIN tarif t ON t.id_layanan = pm.id_layanan AND t.versi_harga = pm.versi_harga
GROUP BY pm.no_registrasi;
ALTER TABLE _tagihan ADD PRIMARY KEY (reg);
ANALYZE _tagihan;

INSERT INTO pembayaran (tanggal_pembayaran, waktu_pembayaran, metode_pembayaran, status_pembayaran, id_pegawai, no_registrasi, jumlah_pembayaran)
SELECT tgl_bayar, jam_bayar, metode, status, kasir, reg, total
FROM (
  SELECT r.reg,
         (r.tgl + r.jam + CASE WHEN r.inap THEN (2 + pg_temp.h(r.reg, 80) % 7) * interval '1 day' ELSE interval '3 hours' END)::date AS tgl_bayar,
         (r.jam + interval '3 hours')::time AS jam_bayar,
         CASE WHEN pg_temp.h(r.reg, 160) % 100 < 80 THEN 'Non-Tunai' ELSE 'Tunai' END AS metode,
         66 + (pg_temp.h(r.reg, 161) % 30)::int AS kasir,
         coalesce(t.total, 0) AS total,
         pg_temp.h(r.reg, 162) % 100 < 5 AS ada_gagal
  FROM _reg r LEFT JOIN _tagihan t ON t.reg = r.reg
) x
CROSS JOIN LATERAL (VALUES ('Gagal', 0), ('Berhasil', 1)) s(status, urut)
WHERE s.urut = 1 OR x.ada_gagal
ORDER BY reg, s.urut;

-- =====================================================================
-- 8. Penutup: sinkronkan sequence IDENTITY, statistik planner
-- =====================================================================
\echo '== Sinkronisasi sequence identity'
DO $$
DECLARE r record; m bigint;
BEGIN
  FOR r IN SELECT table_name, column_name FROM information_schema.columns
           WHERE table_schema = 'public' AND is_identity = 'YES'
  LOOP
    EXECUTE format('SELECT coalesce(max(%I), 0) FROM %I', r.column_name, r.table_name) INTO m;
    IF m > 0 THEN
      PERFORM setval(pg_get_serial_sequence(quote_ident(r.table_name), r.column_name), m);
    END IF;
  END LOOP;
END $$;

\if :cek_fk
\else
  SET session_replication_role = origin;
\endif

\echo '== VACUUM ANALYZE (bisa lama di HDD)'
VACUUM (ANALYZE);

\echo '== Seed selesai. Jalankan hitung_baris.sql untuk ringkasan jumlah baris dan distribusi.'
