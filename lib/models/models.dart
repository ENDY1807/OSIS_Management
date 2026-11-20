import 'dart:convert';

class FileRiwayat {
  String id;
  String namaFile;
  DateTime tanggalUpload;
  List<String> nisList;

  FileRiwayat({
    required this.id,
    required this.namaFile,
    required this.tanggalUpload,
    required this.nisList,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'namaFile': namaFile,
    'tanggalUpload': tanggalUpload.toIso8601String(),
    'nisList': nisList,
  };

  factory FileRiwayat.fromJson(Map<String, dynamic> j) => FileRiwayat(
    id: j['id'] ?? '',
    namaFile: j['namaFile'] ?? '',
    tanggalUpload: DateTime.parse(j['tanggalUpload'] ?? DateTime.now().toIso8601String()),
    nisList: (j['nisList'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}

class Siswa {
  String id;
  String nama;
  String kelas;
  String nis;

  Siswa({required this.id, required this.nama, required this.kelas, required this.nis});

  Map<String, dynamic> toJson() => {'id': id, 'nama': nama, 'kelas': kelas, 'nis': nis};
  
  factory Siswa.fromJson(Map<String, dynamic> j) =>
      Siswa(
        id: j['id'] ?? '', 
        nama: j['nama'] ?? '', 
        kelas: j['kelas'] ?? '', 
        nis: j['nis'] ?? ''
      );
}

class JenisPelanggaran {
  String id;
  String nama;
  List<int> hariAktif; // 1=Senin..5=Jumat, kosong=semua hari

  JenisPelanggaran({required this.id, required this.nama, this.hariAktif = const []});

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'hari_aktif': hariAktif,
  };

  factory JenisPelanggaran.fromJson(Map<String, dynamic> j) => JenisPelanggaran(
    id: j['id'] ?? '',
    nama: j['nama'] ?? '',
    hariAktif: (j['hari_aktif'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [],
  );
}

class Pelanggaran {
  String id;
  String siswaId;
  String jenisId;
  DateTime tanggal;
  String keterangan;
  String? namaSiswa;
  String? kelasSiswa;
  String? nisSiswa;

  Pelanggaran({
    required this.id,
    required this.siswaId,
    required this.jenisId,
    required this.tanggal,
    this.keterangan = '',
    this.namaSiswa,
    this.kelasSiswa,
    this.nisSiswa,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'siswaId': siswaId,
        'jenisId': jenisId,
        'tanggal': tanggal.toIso8601String(),
        'keterangan': keterangan,
        if (namaSiswa != null) 'namaSiswa': namaSiswa,
        if (kelasSiswa != null) 'kelasSiswa': kelasSiswa,
        if (nisSiswa != null) 'nisSiswa': nisSiswa,
      };

  factory Pelanggaran.fromJson(Map<String, dynamic> j) => Pelanggaran(
        id: j['id'] ?? '',
        siswaId: j['siswaId'] ?? j['siswa_id'] ?? '',
        jenisId: j['jenisId'] ?? j['jenis_id'] ?? '',
        tanggal: DateTime.parse(j['tanggal'] ?? DateTime.now().toIso8601String()),
        keterangan: j['keterangan'] ?? '',
        namaSiswa: j['namaSiswa'] ?? j['nama_siswa'] ?? j['siswa_nama'],
        kelasSiswa: j['kelasSiswa'] ?? j['kelas_siswa'] ?? j['siswa_kelas'],
        nisSiswa: j['nisSiswa'] ?? j['nis_siswa'] ?? j['siswa_nis'],
      );
}

class StatusProker {
  static const belum = 'Belum';
  static const berjalan = 'Berjalan';
  static const selesai = 'Selesai';
  static const all = [belum, berjalan, selesai];
}

class Proker {
  String id;
  String nama;
  String deskripsi;
  String sekbid;
  String penanggungJawab;
  DateTime tanggalRencana;
  DateTime? tanggalRealisasi;
  String status;
  String keterangan;
  bool disahkanKepsek;
  String catatanKepsek;
  String tujuanKegiatan;
  String tempatKegiatan;
  int anggaran;
  List<String> dokumentasiUrls;

  Proker({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.sekbid,
    required this.penanggungJawab,
    required this.tanggalRencana,
    this.tanggalRealisasi,
    this.status = StatusProker.belum,
    this.keterangan = '',
    this.disahkanKepsek = false,
    this.catatanKepsek = '',
    this.tujuanKegiatan = '',
    this.tempatKegiatan = '',
    this.anggaran = 0,
    this.dokumentasiUrls = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'deskripsi': deskripsi,
        'sekbid': sekbid,
        'penanggungJawab': penanggungJawab,
        'tanggalRencana': tanggalRencana.toIso8601String(),
        'tanggalRealisasi': tanggalRealisasi?.toIso8601String(),
        'status': status,
        'keterangan': keterangan,
        'disahkanKepsek': disahkanKepsek,
        'catatanKepsek': catatanKepsek,
        'tujuanKegiatan': tujuanKegiatan,
        'tempatKegiatan': tempatKegiatan,
        'anggaran': anggaran,
        'dokumentasiUrls': dokumentasiUrls,
      };
  
  factory Proker.fromJson(Map<String, dynamic> j) => Proker(
        id: j['id'] ?? '',
        nama: j['nama'] ?? '',
        deskripsi: j['deskripsi'] ?? '',
        sekbid: j['sekbid'] ?? '',
        penanggungJawab: j['penanggungJawab'] ?? j['penanggung_jawab'] ?? '',
        tanggalRencana: DateTime.parse(j['tanggalRencana'] ?? j['tanggal_rencana'] ?? DateTime.now().toIso8601String()),
        tanggalRealisasi: (j['tanggalRealisasi'] ?? j['tanggal_realisasi']) != null 
            ? DateTime.parse(j['tanggalRealisasi'] ?? j['tanggal_realisasi']) 
            : null,
        status: j['status'] ?? StatusProker.belum,
        keterangan: j['keterangan'] ?? '',
        disahkanKepsek: (j['disahkanKepsek'] ?? j['disahkan_kepsek']) == true || (j['disahkanKepsek'] ?? j['disahkan_kepsek']) == 1,
        catatanKepsek: j['catatanKepsek'] ?? j['catatan_kepsek'] ?? '',
        tujuanKegiatan: j['tujuanKegiatan'] ?? j['tujuan_kegiatan'] ?? '',
        tempatKegiatan: j['tempatKegiatan'] ?? j['tempat_kegiatan'] ?? '',
        anggaran: (j['anggaran'] as num?)?.toInt() ?? 0,
        dokumentasiUrls: (j['dokumentasiUrls'] ?? j['dokumentasi_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class KategoriArsip {
  static const surat = 'Surat';
  static const proposal = 'Proposal';
  static const lpj = 'LPJ';
  static const sk = 'SK';
  static const notulen = 'Notulen';
  static const lainnya = 'Lainnya';
  static const all = [surat, proposal, lpj, sk, notulen, lainnya];
}

class Arsip {
  String id;
  String judul;
  String kategori;
  String deskripsi;
  String nomorSurat;
  DateTime tanggal;
  String pembuatId;
  String fileUrl;
  String keterangan;

  Arsip({
    required this.id,
    required this.judul,
    required this.kategori,
    this.deskripsi = '',
    this.nomorSurat = '',
    required this.tanggal,
    required this.pembuatId,
    this.fileUrl = '',
    this.keterangan = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'kategori': kategori,
        'deskripsi': deskripsi,
        'nomorSurat': nomorSurat,
        'tanggal': tanggal.toIso8601String(),
        'pembuatId': pembuatId,
        'fileUrl': fileUrl,
        'keterangan': keterangan,
      };
  
  factory Arsip.fromJson(Map<String, dynamic> j) => Arsip(
        id: j['id'] ?? '',
        judul: j['judul'] ?? '',
        kategori: j['kategori'] ?? KategoriArsip.lainnya,
        deskripsi: j['deskripsi'] ?? '',
        nomorSurat: j['nomorSurat'] ?? j['nomor_surat'] ?? '',
        tanggal: DateTime.parse(j['tanggal'] ?? DateTime.now().toIso8601String()),
        pembuatId: j['pembuatId'] ?? j['pembuat_id'] ?? '',
        fileUrl: j['fileUrl'] ?? j['file_url'] ?? '',
        keterangan: j['keterangan'] ?? '',
      );
}

class StatusLaporan {
  static const draft = 'Draft';
  static const selesai = 'Selesai';
  static const all = [draft, selesai];
}

class LaporanKegiatan {
  String id;
  String judul;
  String sekbid;
  String penanggungJawab;
  DateTime tanggalKegiatan;
  String lokasi;
  String deskripsi;
  String hasilCapaian;
  String kendalaSaran;
  String status;
  DateTime tanggalBuat;
  List<String> peserta;
  String pembuatId; // username pembuat

  LaporanKegiatan({
    required this.id,
    required this.judul,
    required this.sekbid,
    required this.penanggungJawab,
    required this.tanggalKegiatan,
    this.lokasi = '',
    this.deskripsi = '',
    this.hasilCapaian = '',
    this.kendalaSaran = '',
    this.status = StatusLaporan.draft,
    required this.tanggalBuat,
    this.peserta = const [],
    this.pembuatId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'sekbid': sekbid,
        'penanggungJawab': penanggungJawab,
        'tanggalKegiatan': tanggalKegiatan.toIso8601String(),
        'lokasi': lokasi,
        'deskripsi': deskripsi,
        'hasilCapaian': hasilCapaian,
        'kendalaSaran': kendalaSaran,
        'status': status,
        'tanggalBuat': tanggalBuat.toIso8601String(),
        'peserta': peserta,
        'pembuatId': pembuatId,
      };
  
  factory LaporanKegiatan.fromJson(Map<String, dynamic> j) => LaporanKegiatan(
        id: j['id'] ?? '',
        judul: j['judul'] ?? '',
        sekbid: j['sekbid'] ?? '',
        penanggungJawab: j['penanggungJawab'] ?? j['penanggung_jawab'] ?? '',
        tanggalKegiatan: DateTime.parse(j['tanggalKegiatan'] ?? j['tanggal_kegiatan'] ?? DateTime.now().toIso8601String()),
        lokasi: j['lokasi'] ?? '',
        deskripsi: j['deskripsi'] ?? '',
        hasilCapaian: j['hasilCapaian'] ?? j['hasil_capaian'] ?? '',
        kendalaSaran: j['kendalaSaran'] ?? j['kendala_saran'] ?? '',
        status: j['status'] ?? StatusLaporan.draft,
        tanggalBuat: DateTime.parse(j['tanggalBuat'] ?? j['tanggal_buat'] ?? DateTime.now().toIso8601String()),
        peserta: (j['peserta'] as List?)?.map((e) => e.toString()).toList() ?? [],
        pembuatId: j['pembuatId'] ?? j['pembuat_id'] ?? '',
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String category; // 'arsip', 'laporan', 'proker', 'system'
  final DateTime timestamp;
  final String actor;
  final List<String> targetRoles;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    required this.actor,
    this.targetRoles = const [],
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
        'actor': actor,
        'targetRoles': targetRoles,
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        category: j['category'] ?? 'system',
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
        actor: j['actor'] ?? '',
        targetRoles: (j['targetRoles'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isRead: j['isRead'] ?? false,
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        category: category,
        timestamp: timestamp,
        actor: actor,
        targetRoles: targetRoles,
        isRead: isRead ?? this.isRead,
      );
}

class SekbidItem {
  String id;
  String name;
  String deskripsi;
  int urutan;

  SekbidItem({
    required this.id,
    required this.name,
    this.deskripsi = '',
    this.urutan = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deskripsi': deskripsi,
    'urutan': urutan,
  };

  factory SekbidItem.fromJson(Map<String, dynamic> j) => SekbidItem(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? j['nama']?.toString() ?? '',
    deskripsi: j['deskripsi']?.toString() ?? '',
    urutan: (j['urutan'] as num?)?.toInt() ?? 0,
  );
}

class KategoriKebaikan {
  static const ibadah = 'Ibadah & Akhlak Mulia';
  static const kejujuran = 'Kejujuran & Integritas';
  static const sosial = 'Kepedulian Sosial & Gotong Royong';
  static const prestasi = 'Prestasi & Akademik';
  static const lingkungan = 'Kebersihan & Lingkungan';
  static const kedisiplinan = 'Ketertiban & Kedisiplinan';
  static const lainnya = 'Lainnya';

  static const all = [
    ibadah,
    kejujuran,
    sosial,
    prestasi,
    lingkungan,
    kedisiplinan,
    lainnya,
  ];
}

class CatatanKebaikan {
  String id;
  String siswaId;
  String judul;
  String kategori;
  int poin;
  DateTime tanggal;
  String keterangan;
  String? namaSiswa;
  String? kelasSiswa;
  String? nisSiswa;
  String petugas;
  String apresiasi;

  CatatanKebaikan({
    required this.id,
    required this.siswaId,
    required this.judul,
    this.kategori = KategoriKebaikan.ibadah,
    this.poin = 10,
    required this.tanggal,
    this.keterangan = '',
    this.namaSiswa,
    this.kelasSiswa,
    this.nisSiswa,
    this.petugas = '',
    this.apresiasi = 'Pujian Lisan & Catatan Prestasi',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'siswaId': siswaId,
    'judul': judul,
    'kategori': kategori,
    'poin': poin,
    'tanggal': tanggal.toIso8601String(),
    'keterangan': keterangan,
    if (namaSiswa != null) 'namaSiswa': namaSiswa,
    if (kelasSiswa != null) 'kelasSiswa': kelasSiswa,
    if (nisSiswa != null) 'nisSiswa': nisSiswa,
    'petugas': petugas,
    'apresiasi': apresiasi,
  };

  factory CatatanKebaikan.fromJson(Map<String, dynamic> j) => CatatanKebaikan(
    id: j['id'] ?? '',
    siswaId: j['siswaId'] ?? j['siswa_id'] ?? '',
    judul: j['judul'] ?? j['nama'] ?? 'Aksi Kebaikan',
    kategori: j['kategori'] ?? KategoriKebaikan.ibadah,
    poin: (j['poin'] as num?)?.toInt() ?? 10,
    tanggal: DateTime.parse(j['tanggal'] ?? DateTime.now().toIso8601String()),
    keterangan: j['keterangan'] ?? '',
    namaSiswa: j['namaSiswa'] ?? j['nama_siswa'] ?? j['siswa_nama'],
    kelasSiswa: j['kelasSiswa'] ?? j['kelas_siswa'] ?? j['siswa_kelas'],
    nisSiswa: j['nisSiswa'] ?? j['nis_siswa'] ?? j['siswa_nis'],
    petugas: j['petugas'] ?? '',
    apresiasi: j['apresiasi'] ?? 'Pujian Lisan & Catatan Prestasi',
  );
}

// ── SISTEM KAS & ABSENSI OSIS ──────────────────────────────────────────────

class AnggotaOsis {
  String id;
  String nama;
  String jabatan; // 'Ketua OSIS', 'Wakil Ketua OSIS', 'Sekretaris', 'Bendahara', 'Sekbid 1'...'Sekbid 10', 'Anggota'
  String kelas;
  String nis;
  String nisn;
  String jurusan;
  String noHp;
  String alamat;
  String fotoUrl;
  String bidang; // 'BPH', 'SEKBID1'..'SEKBID10', 'Anggota'
  String statusKeaktifan; // 'Aktif', 'Non-aktif', 'Alumni'
  bool aktif;

  AnggotaOsis({
    required this.id,
    required this.nama,
    required this.jabatan,
    this.kelas = '',
    this.nis = '',
    this.nisn = '',
    this.jurusan = '',
    this.noHp = '',
    this.alamat = '',
    this.fotoUrl = '',
    this.bidang = 'Anggota',
    this.statusKeaktifan = 'Aktif',
    this.aktif = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'jabatan': jabatan,
    'kelas': kelas,
    'nis': nis,
    'nisn': nisn,
    'jurusan': jurusan,
    'no_hp': noHp,
    'alamat': alamat,
    'foto_url': fotoUrl,
    'bidang': bidang,
    'status_keaktifan': statusKeaktifan,
    'aktif': aktif,
  };

  factory AnggotaOsis.fromJson(Map<String, dynamic> j) => AnggotaOsis(
    id: j['id']?.toString() ?? '',
    nama: j['nama']?.toString() ?? '',
    jabatan: j['jabatan']?.toString() ?? 'Anggota',
    kelas: j['kelas']?.toString() ?? '',
    nis: j['nis']?.toString() ?? '',
    nisn: j['nisn']?.toString() ?? '',
    jurusan: j['jurusan']?.toString() ?? '',
    noHp: j['no_hp']?.toString() ?? j['noHp']?.toString() ?? '',
    alamat: j['alamat']?.toString() ?? '',
    fotoUrl: j['foto_url']?.toString() ?? j['fotoUrl']?.toString() ?? '',
    bidang: j['bidang']?.toString() ?? (j['jabatan']?.toString().startsWith('Sekbid') == true ? j['jabatan'].toString() : 'Anggota'),
    statusKeaktifan: j['status_keaktifan']?.toString() ?? ((j['aktif'] == false) ? 'Non-aktif' : 'Aktif'),
    aktif: j['aktif'] != false && j['status_keaktifan'] != 'Non-aktif',
  );
}

class KasOsisItem {
  String anggotaId;
  String nama;
  String jabatan;
  String kelas;
  bool sudahBayar;
  int nominalBayar;
  DateTime? tanggalBayar;
  String catatan;

  KasOsisItem({
    required this.anggotaId,
    required this.nama,
    required this.jabatan,
    this.kelas = '',
    this.sudahBayar = false,
    this.nominalBayar = 0,
    this.tanggalBayar,
    this.catatan = '',
  });

  Map<String, dynamic> toJson() => {
    'anggota_id': anggotaId,
    'nama': nama,
    'jabatan': jabatan,
    'kelas': kelas,
    'sudah_bayar': sudahBayar,
    'nominal_bayar': nominalBayar,
    'tanggal_bayar': tanggalBayar?.toIso8601String(),
    'catatan': catatan,
  };

  factory KasOsisItem.fromJson(Map<String, dynamic> j) => KasOsisItem(
    anggotaId: j['anggota_id']?.toString() ?? j['anggotaId']?.toString() ?? '',
    nama: j['nama']?.toString() ?? '',
    jabatan: j['jabatan']?.toString() ?? '',
    kelas: j['kelas']?.toString() ?? '',
    sudahBayar: j['sudah_bayar'] == true || j['sudahBayar'] == true,
    nominalBayar: (j['nominal_bayar'] ?? j['nominalBayar'] as num?)?.toInt() ?? 0,
    tanggalBayar: (j['tanggal_bayar'] ?? j['tanggalBayar']) != null
        ? DateTime.tryParse((j['tanggal_bayar'] ?? j['tanggalBayar']).toString())
        : null,
    catatan: j['catatan']?.toString() ?? '',
  );
}

class KasOsisSession {
  String id;
  DateTime tanggal;
  String judul;
  int nominalWajib;
  String keterangan;
  String petugas;
  List<KasOsisItem> items;
  DateTime updatedAt;

  KasOsisSession({
    required this.id,
    required this.tanggal,
    required this.judul,
    this.nominalWajib = 5000,
    this.keterangan = '',
    this.petugas = 'BENDAHARA',
    required this.items,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  int get totalTerkumpul =>
      items.where((i) => i.sudahBayar).fold(0, (sum, i) => sum + (i.nominalBayar > 0 ? i.nominalBayar : nominalWajib));

  int get jumlahSudahBayar => items.where((i) => i.sudahBayar).length;
  int get jumlahBelumBayar => items.where((i) => !i.sudahBayar).length;
  int get totalTarget => items.length * nominalWajib;
  int get totalLunas => jumlahSudahBayar;
  double get persentaseBayar => items.isEmpty ? 0.0 : (jumlahSudahBayar / items.length) * 100.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tanggal': tanggal.toIso8601String(),
    'judul': judul,
    'nominal_wajib': nominalWajib,
    'keterangan': keterangan,
    'petugas': petugas,
    'items': items.map((i) => i.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory KasOsisSession.fromJson(Map<String, dynamic> j) {
    dynamic rawItems = j['items'];
    if (rawItems is String) {
      try {
        rawItems = jsonDecode(rawItems);
      } catch (_) {}
    }
    return KasOsisSession(
      id: j['id']?.toString() ?? '',
      tanggal: DateTime.tryParse(j['tanggal']?.toString() ?? '') ?? DateTime.now(),
      judul: j['judul']?.toString() ?? 'Uang Kas OSIS',
      nominalWajib: (j['nominal_wajib'] ?? j['nominalWajib'] as num?)?.toInt() ?? 5000,
      keterangan: j['keterangan']?.toString() ?? '',
      petugas: j['petugas']?.toString() ?? 'BENDAHARA',
      items: (rawItems as List?)
              ?.map((e) => KasOsisItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class KasOsisTransaksi {
  String id;
  DateTime tanggal;
  String jenis; // 'masuk' atau 'keluar'
  String judul;
  int nominal;
  String kategori; // 'Kas Mingguan', 'Konsumsi Rapat', 'ATK & Fotokopi', 'Kegiatan Proker', 'Lainnya'
  String penanggungJawab;
  String keterangan;
  String buktiUrl;
  String? prokerId;

  KasOsisTransaksi({
    required this.id,
    required this.tanggal,
    required this.jenis,
    required this.judul,
    required this.nominal,
    this.kategori = 'Lainnya',
    this.penanggungJawab = '',
    this.keterangan = '',
    this.buktiUrl = '',
    this.prokerId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tanggal': tanggal.toIso8601String(),
    'jenis': jenis,
    'judul': judul,
    'nominal': nominal,
    'kategori': kategori,
    'penanggung_jawab': penanggungJawab,
    'keterangan': keterangan,
    'bukti_url': buktiUrl,
    if (prokerId != null) 'proker_id': prokerId,
  };

  factory KasOsisTransaksi.fromJson(Map<String, dynamic> j) => KasOsisTransaksi(
    id: j['id']?.toString() ?? '',
    tanggal: DateTime.tryParse(j['tanggal']?.toString() ?? '') ?? DateTime.now(),
    jenis: j['jenis']?.toString() ?? 'masuk',
    judul: j['judul']?.toString() ?? '',
    nominal: (j['nominal'] as num?)?.toInt() ?? 0,
    kategori: j['kategori']?.toString() ?? 'Lainnya',
    penanggungJawab: j['penanggung_jawab']?.toString() ?? j['penanggungJawab']?.toString() ?? '',
    keterangan: j['keterangan']?.toString() ?? '',
    buktiUrl: j['bukti_url']?.toString() ?? j['buktiUrl']?.toString() ?? '',
    prokerId: j['proker_id']?.toString() ?? j['prokerId']?.toString(),
  );
}

class AbsensiOsisItem {
  String anggotaId;
  String nama;
  String jabatan;
  String kelas;
  String status; // 'Hadir', 'Izin', 'Sakit', 'Alpa'
  String keterangan;

  AbsensiOsisItem({
    required this.anggotaId,
    required this.nama,
    required this.jabatan,
    this.kelas = '',
    this.status = 'Hadir',
    this.keterangan = '',
  });

  Map<String, dynamic> toJson() => {
    'anggota_id': anggotaId,
    'nama': nama,
    'jabatan': jabatan,
    'kelas': kelas,
    'status': status,
    'keterangan': keterangan,
  };

  factory AbsensiOsisItem.fromJson(Map<String, dynamic> j) => AbsensiOsisItem(
    anggotaId: j['anggota_id']?.toString() ?? j['anggotaId']?.toString() ?? '',
    nama: j['nama']?.toString() ?? '',
    jabatan: j['jabatan']?.toString() ?? '',
    kelas: j['kelas']?.toString() ?? '',
    status: j['status']?.toString() ?? 'Hadir',
    keterangan: j['keterangan']?.toString() ?? '',
  );
}

class AbsensiOsisSession {
  String id;
  DateTime tanggal;
  String namaKegiatan;
  String lokasi;
  String petugas;
  String keterangan;
  String tipeKegiatan; // 'Rapat OSIS', 'Kegiatan OSIS', 'Piket OSIS'
  List<AbsensiOsisItem> items;
  DateTime updatedAt;

  AbsensiOsisSession({
    required this.id,
    required this.tanggal,
    required this.namaKegiatan,
    this.lokasi = 'Sekretariat OSIS',
    this.petugas = '',
    this.keterangan = '',
    this.tipeKegiatan = 'Rapat OSIS',
    required this.items,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  int get totalHadir => items.where((i) => i.status == 'Hadir').length;
  int get totalIzin  => items.where((i) => i.status == 'Izin').length;
  int get totalSakit => items.where((i) => i.status == 'Sakit').length;
  int get totalAlpa  => items.where((i) => i.status == 'Alpa').length;
  double get persentaseHadir => items.isEmpty ? 0.0 : (totalHadir / items.length) * 100.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tanggal': tanggal.toIso8601String(),
    'nama_kegiatan': namaKegiatan,
    'lokasi': lokasi,
    'petugas': petugas,
    'keterangan': keterangan,
    'tipe_kegiatan': tipeKegiatan,
    'items': items.map((i) => i.toJson()).toList(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory AbsensiOsisSession.fromJson(Map<String, dynamic> j) {
    dynamic rawItems = j['items'];
    if (rawItems is String) {
      try {
        rawItems = jsonDecode(rawItems);
      } catch (_) {}
    }
    return AbsensiOsisSession(
      id: j['id']?.toString() ?? '',
      tanggal: DateTime.tryParse(j['tanggal']?.toString() ?? '') ?? DateTime.now(),
      namaKegiatan: j['nama_kegiatan']?.toString() ?? j['namaKegiatan']?.toString() ?? 'Kegiatan OSIS',
      lokasi: j['lokasi']?.toString() ?? 'Sekretariat OSIS',
      petugas: j['petugas']?.toString() ?? '',
      keterangan: j['keterangan']?.toString() ?? '',
      tipeKegiatan: j['tipe_kegiatan']?.toString() ?? j['tipeKegiatan']?.toString() ?? 'Rapat OSIS',
      items: (rawItems as List?)
              ?.map((e) => AbsensiOsisItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ── 1. PROFIL OSIS & ORGANISASI ──────────────────────────────────────────

class ProfilOsis {
  String namaOrganisasi;
  String namaSekolah;
  String logoOsisUrl;
  String logoSekolahUrl;
  String visi;
  List<String> misi;
  String masaBakti;
  String namaKetua;
  String namaWakil;
  String namaPembina;
  String namaSekretaris;
  String namaBendahara;
  String adArt;
  String gbho;
  String deskripsi;
  DateTime updatedAt;

  ProfilOsis({
    this.namaOrganisasi = 'OSIS SMK Bakti Nusantara 666',
    this.namaSekolah = 'SMK Bakti Nusantara 666',
    this.logoOsisUrl = '',
    this.logoSekolahUrl = '',
    this.visi = 'Mewujudkan OSIS yang berintegritas, kreatif, disiplin, berdaya saing global, serta berlandaskan nilai-nilai ketakwaan dan budaya bangsa.',
    this.misi = const [
      'Meningkatkan keimanan dan ketaqwaan seluruh pengurus dan warga sekolah.',
      'Menjadi wadah aspirasi, kreativitas, dan inovasi siswa di berbagai bidang.',
      'Mengembangkan kedisiplinan dan profesionalisme organisasi melalui kegiatan terprogram.',
      'Mempererat tali persaudaraan dan solidaritas antarsiswa serta hubungan dengan pihak luar.',
      'Mengoptimalkan pemanfaatan teknologi digital dalam tata kelola organisasi.',
    ],
    this.masaBakti = '2026 / 2027',
    this.namaKetua = 'Ketua OSIS',
    this.namaWakil = 'Wakil Ketua OSIS',
    this.namaPembina = 'Pembina OSIS',
    this.namaSekretaris = 'Sekretaris OSIS',
    this.namaBendahara = 'Bendahara OSIS',
    this.adArt = '''BAB I: NAMA, WAKTU, DAN TEMPAT KEDUDUKAN
Pasal 1: Organisasi ini bernama Organisasi Siswa Intra Sekolah (OSIS).
Pasal 2: OSIS didirikan untuk jangka waktu tidak terbatas.
Pasal 3: OSIS berkedudukan di lingkungan sekolah resmi.

BAB II: ASAS, TUJUAN, DAN SIFAT
Pasal 4: OSIS berasaskan Pancasila dan Undang-Undang Dasar 1945.
Pasal 5: Bertujuan mempersiapkan kader penerus perjuangan bangsa, membina kepribadian luhur, dan memupuk rasa persaudaraan.
Pasal 6: OSIS bersifat intra sekolah dan merupakan satu-satunya organisasi siswa yang sah di sekolah.

BAB III: KEANGGOTAAN DAN KEPENGURUSAN
Pasal 7: Anggota OSIS adalah seluruh siswa yang terdaftar aktif di sekolah.
Pasal 8: Pengurus OSIS adalah siswa terpilih melalui mekanisme seleksi dan musyawarah/pemilihan resmi.
Pasal 9: Masa bakti kepengurusan adalah 1 (satu) tahun pelajaran.

BAB IV: HAK DAN KEWAJIBAN
Pasal 10: Setiap pengurus berkewajiban menaati tata tertib, menjunjung tinggi nama baik sekolah, dan aktif menjalankan proker.
Pasal 11: Pengurus berhak menyampaikan aspirasi, usulan, serta mendapatkan pembinaan.''',
    this.gbho = '''GARIS-GARIS BESAR HALUAN ORGANISASI (GBHO)

I. POLA DASAR PENGEMBANGAN ORGANISASI
1. Penguatan kelembagaan OSIS yang transparan, akuntabel, dan digital-first.
2. Membangun sinergi aktif antara Pengurus OSIS, Pembina, Kepala Sekolah, dan Majelis Perwakilan Kelas.

II. SASARAN UMUM KEPENGURUSAN
1. Terlaksananya 100% program kerja pokok dari seluruh Sekbid 1 hingga Sekbid 10.
2. Peningkatan partisipasi siswa dalam kegiatan akademik, bakat minat, keagamaan, dan sosial kemasyarakatan.
3. Tertib administrasi persuratan, inventarisasi aset, dan tata kelola keuangan yang transparan.

III. ARAH KEBIJAKAN BIDANG
- Sekbid 1: Pembinaan keimanan, ketakwaan, dan toleransi beragama.
- Sekbid 2: Penguatan budi pekerti, etika, dan karakter siswa.
- Sekbid 3: Kedisiplinan, wawasan kebangsaan, dan bela negara.
- Sekbid 4: Prestasi akademik, literasi, dan olimpiade keilmuan.
- Sekbid 5: Demokrasi, HAM, pendidikan politik, dan keterbukaan publik.
- Sekbid 6: Kewirausahaan kreatif, kemandirian dana, dan bazar sekolah.
- Sekbid 7: Kebugaran jasmani, turnamen olahraga, dan pola hidup sehat.
- Sekbid 8: Apresiasi seni sastra, festival musik, tari, dan kebudayaan daerah.
- Sekbid 9: Penguasaan teknologi informasi, publikasi multimedia, dan inovasi aplikasi.
- Sekbid 10: Kemampuan komunikasi bilingual (Bahasa Indonesia & Bahasa Asing), public speaking, dan kehumasan.''',
    this.deskripsi = 'Organisasi Siswa Intra Sekolah resmi sebagai wadah utama kepemimpinan dan kegiatan siswa.',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'nama_organisasi': namaOrganisasi,
    'nama_sekolah': namaSekolah,
    'logo_osis_url': logoOsisUrl,
    'logo_sekolah_url': logoSekolahUrl,
    'visi': visi,
    'misi': misi,
    'masa_bakti': masaBakti,
    'nama_ketua': namaKetua,
    'nama_wakil': namaWakil,
    'nama_pembina': namaPembina,
    'nama_sekretaris': namaSekretaris,
    'nama_bendahara': namaBendahara,
    'ad_art': adArt,
    'gbho': gbho,
    'deskripsi': deskripsi,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory ProfilOsis.fromJson(Map<String, dynamic> j) {
    dynamic rawMisi = j['misi'];
    List<String> parsedMisi = [];
    if (rawMisi is List) {
      parsedMisi = rawMisi.map((e) => e.toString()).toList();
    } else if (rawMisi is String) {
      try {
        final decoded = jsonDecode(rawMisi);
        if (decoded is List) parsedMisi = decoded.map((e) => e.toString()).toList();
      } catch (_) {
        parsedMisi = [rawMisi];
      }
    }
    return ProfilOsis(
      namaOrganisasi: j['nama_organisasi']?.toString() ?? 'OSIS SMK Bakti Nusantara 666',
      namaSekolah: j['nama_sekolah']?.toString() ?? 'SMK Bakti Nusantara 666',
      logoOsisUrl: j['logo_osis_url']?.toString() ?? '',
      logoSekolahUrl: j['logo_sekolah_url']?.toString() ?? '',
      visi: j['visi']?.toString() ?? 'Mewujudkan OSIS yang berintegritas, kreatif, disiplin, berdaya saing global, serta berlandaskan nilai-nilai ketakwaan dan budaya bangsa.',
      misi: parsedMisi.isNotEmpty ? parsedMisi : ProfilOsis().misi,
      masaBakti: j['masa_bakti']?.toString() ?? '2026 / 2027',
      namaKetua: j['nama_ketua']?.toString() ?? 'Ketua OSIS',
      namaWakil: j['nama_wakil']?.toString() ?? 'Wakil Ketua OSIS',
      namaPembina: j['nama_pembina']?.toString() ?? 'Pembina OSIS',
      namaSekretaris: j['nama_sekretaris']?.toString() ?? 'Sekretaris OSIS',
      namaBendahara: j['nama_bendahara']?.toString() ?? 'Bendahara OSIS',
      adArt: j['ad_art']?.toString() ?? ProfilOsis().adArt,
      gbho: j['gbho']?.toString() ?? ProfilOsis().gbho,
      deskripsi: j['deskripsi']?.toString() ?? 'Organisasi Siswa Intra Sekolah resmi.',
      updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ── 3. INVENTARIS OSIS ────────────────────────────────────────────────────

class InventarisOsis {
  String id;
  String namaBarang;
  String kodeBarang;
  String kategori; // 'Elektronik', 'ATK & Kantor', 'Perlengkapan Acara', 'Olahraga & Seni', 'Lainnya'
  int jumlah;
  String kondisi; // 'Baik', 'Rusak Ringan', 'Rusak Berat'
  String lokasiSimpan;
  String statusPeminjaman; // 'Tersedia', 'Dipinjam', 'Dalam Perbaikan'
  String peminjam;
  DateTime tanggalMasuk;
  String keterangan;

  InventarisOsis({
    required this.id,
    required this.namaBarang,
    this.kodeBarang = '',
    this.kategori = 'Perlengkapan Acara',
    this.jumlah = 1,
    this.kondisi = 'Baik',
    this.lokasiSimpan = 'Ruang OSIS',
    this.statusPeminjaman = 'Tersedia',
    this.peminjam = '',
    DateTime? tanggalMasuk,
    this.keterangan = '',
  }) : tanggalMasuk = tanggalMasuk ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama_barang': namaBarang,
    'kode_barang': kodeBarang,
    'kategori': kategori,
    'jumlah': jumlah,
    'kondisi': kondisi,
    'lokasi_simpan': lokasiSimpan,
    'status_peminjaman': statusPeminjaman,
    'peminjam': peminjam,
    'tanggal_masuk': tanggalMasuk.toIso8601String(),
    'keterangan': keterangan,
  };

  factory InventarisOsis.fromJson(Map<String, dynamic> j) => InventarisOsis(
    id: j['id']?.toString() ?? '',
    namaBarang: j['nama_barang']?.toString() ?? j['namaBarang']?.toString() ?? '',
    kodeBarang: j['kode_barang']?.toString() ?? j['kodeBarang']?.toString() ?? '',
    kategori: j['kategori']?.toString() ?? 'Perlengkapan Acara',
    jumlah: (j['jumlah'] as num?)?.toInt() ?? 1,
    kondisi: j['kondisi']?.toString() ?? 'Baik',
    lokasiSimpan: j['lokasi_simpan']?.toString() ?? j['lokasiSimpan']?.toString() ?? 'Ruang OSIS',
    statusPeminjaman: j['status_peminjaman']?.toString() ?? j['statusPeminjaman']?.toString() ?? 'Tersedia',
    peminjam: j['peminjam']?.toString() ?? '',
    tanggalMasuk: DateTime.tryParse(j['tanggal_masuk']?.toString() ?? '') ?? DateTime.now(),
    keterangan: j['keterangan']?.toString() ?? '',
  );
}

// ── 5. KALENDER & AGENDA KEGIATAN ─────────────────────────────────────────

class AgendaOsis {
  String id;
  String judul;
  String kategori; // 'Rapat OSIS', 'Kegiatan Sekolah', 'Perlombaan', 'Kegiatan Bidang', 'Agenda Tahunan'
  String bidang; // 'BPH', 'SEKBID1'..'SEKBID10', 'Sekolah'
  DateTime waktuMulai;
  DateTime? waktuSelesai;
  String lokasi;
  String penanggungJawab;
  String deskripsi;
  String status; // 'Akan Datang', 'Sedang Berlangsung', 'Selesai', 'Dibatalkan'
  bool pengingat;

  AgendaOsis({
    required this.id,
    required this.judul,
    this.kategori = 'Rapat OSIS',
    this.bidang = 'BPH',
    required this.waktuMulai,
    this.waktuSelesai,
    this.lokasi = 'Ruang OSIS',
    this.penanggungJawab = '',
    this.deskripsi = '',
    this.status = 'Akan Datang',
    this.pengingat = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'judul': judul,
    'kategori': kategori,
    'bidang': bidang,
    'waktu_mulai': waktuMulai.toIso8601String(),
    'waktu_selesai': waktuSelesai?.toIso8601String(),
    'lokasi': lokasi,
    'penanggung_jawab': penanggungJawab,
    'deskripsi': deskripsi,
    'status': status,
    'pengingat': pengingat,
  };

  factory AgendaOsis.fromJson(Map<String, dynamic> j) => AgendaOsis(
    id: j['id']?.toString() ?? '',
    judul: j['judul']?.toString() ?? '',
    kategori: j['kategori']?.toString() ?? 'Rapat OSIS',
    bidang: j['bidang']?.toString() ?? 'BPH',
    waktuMulai: DateTime.tryParse(j['waktu_mulai']?.toString() ?? '') ?? DateTime.now(),
    waktuSelesai: j['waktu_selesai'] != null ? DateTime.tryParse(j['waktu_selesai'].toString()) : null,
    lokasi: j['lokasi']?.toString() ?? 'Ruang OSIS',
    penanggungJawab: j['penanggung_jawab']?.toString() ?? j['penanggungJawab']?.toString() ?? '',
    deskripsi: j['deskripsi']?.toString() ?? '',
    status: j['status']?.toString() ?? 'Akan Datang',
    pengingat: j['pengingat'] != false,
  );
}

// ── 8. INFORMASI & PENGUMUMAN ──────────────────────────────────────────────

class PengumumanOsis {
  String id;
  String judul;
  String isi;
  String pengirim;
  String rolePengirim; // 'Ketua OSIS', 'Pembina OSIS', 'Sekretaris', 'Koordinator Bidang', 'Admin'
  String kategori; // 'Ketua OSIS', 'Pembina OSIS', 'Rapat', 'Kegiatan', 'Tugas Bidang', 'Umum'
  String targetBidang; // 'Semua', 'BPH', 'SEKBID1'..'SEKBID10'
  DateTime tanggal;
  String lampiranUrl;
  bool isPinned;

  PengumumanOsis({
    required this.id,
    required this.judul,
    required this.isi,
    required this.pengirim,
    this.rolePengirim = 'Ketua OSIS',
    this.kategori = 'Umum',
    this.targetBidang = 'Semua',
    DateTime? tanggal,
    this.lampiranUrl = '',
    this.isPinned = false,
  }) : tanggal = tanggal ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'judul': judul,
    'isi': isi,
    'pengirim': pengirim,
    'role_pengirim': rolePengirim,
    'kategori': kategori,
    'target_bidang': targetBidang,
    'tanggal': tanggal.toIso8601String(),
    'lampiran_url': lampiranUrl,
    'is_pinned': isPinned,
  };

  factory PengumumanOsis.fromJson(Map<String, dynamic> j) => PengumumanOsis(
    id: j['id']?.toString() ?? '',
    judul: j['judul']?.toString() ?? '',
    isi: j['isi']?.toString() ?? '',
    pengirim: j['pengirim']?.toString() ?? '',
    rolePengirim: j['role_pengirim']?.toString() ?? 'Ketua OSIS',
    kategori: j['kategori']?.toString() ?? 'Umum',
    targetBidang: j['target_bidang']?.toString() ?? 'Semua',
    tanggal: DateTime.tryParse(j['tanggal']?.toString() ?? '') ?? DateTime.now(),
    lampiranUrl: j['lampiran_url']?.toString() ?? '',
    isPinned: j['is_pinned'] == true,
  );
}

// ── 9. DOKUMENTASI KEGIATAN ───────────────────────────────────────────────

class DokumentasiKegiatan {
  String id;
  String judul;
  String kategori; // 'Rapat', 'Perlombaan', 'Kegiatan Sosial', 'Kegiatan Sekolah', 'Lainnya'
  DateTime tanggal;
  String deskripsi;
  List<String> fotoUrls;
  String videoUrl;
  String bidang;
  String penanggungJawab;

  DokumentasiKegiatan({
    required this.id,
    required this.judul,
    this.kategori = 'Kegiatan Sekolah',
    required this.tanggal,
    this.deskripsi = '',
    this.fotoUrls = const [],
    this.videoUrl = '',
    this.bidang = 'Semua',
    this.penanggungJawab = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'judul': judul,
    'kategori': kategori,
    'tanggal': tanggal.toIso8601String(),
    'deskripsi': deskripsi,
    'foto_urls': fotoUrls,
    'video_url': videoUrl,
    'bidang': bidang,
    'penanggung_jawab': penanggungJawab,
  };

  factory DokumentasiKegiatan.fromJson(Map<String, dynamic> j) => DokumentasiKegiatan(
    id: j['id']?.toString() ?? '',
    judul: j['judul']?.toString() ?? '',
    kategori: j['kategori']?.toString() ?? 'Kegiatan Sekolah',
    tanggal: DateTime.tryParse(j['tanggal']?.toString() ?? '') ?? DateTime.now(),
    deskripsi: j['deskripsi']?.toString() ?? '',
    fotoUrls: (j['foto_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
    videoUrl: j['video_url']?.toString() ?? '',
    bidang: j['bidang']?.toString() ?? 'Semua',
    penanggungJawab: j['penanggung_jawab']?.toString() ?? '',
  );
}

// ── 10. EVALUASI DAN PENILAIAN KINERJA ────────────────────────────────────

class EvaluasiProker {
  String id;
  String prokerId;
  String namaProker;
  String sekbid;
  DateTime tanggalEvaluasi;
  String hasilCapaian;
  String kendala;
  String saranMasukan;
  int nilaiKinerja; // 1 - 100
  String penilai;
  String rekomendasi;

  EvaluasiProker({
    required this.id,
    required this.prokerId,
    required this.namaProker,
    required this.sekbid,
    DateTime? tanggalEvaluasi,
    this.hasilCapaian = '',
    this.kendala = '',
    this.saranMasukan = '',
    this.nilaiKinerja = 85,
    this.penilai = 'Pembina OSIS',
    this.rekomendasi = 'Dilanjutkan dengan peningkatan efisiensi koordinasi.',
  }) : tanggalEvaluasi = tanggalEvaluasi ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'proker_id': prokerId,
    'nama_proker': namaProker,
    'sekbid': sekbid,
    'tanggal_evaluasi': tanggalEvaluasi.toIso8601String(),
    'hasil_capaian': hasilCapaian,
    'kendala': kendala,
    'saran_masukan': saranMasukan,
    'nilai_kinerja': nilaiKinerja,
    'penilai': penilai,
    'rekomendasi': rekomendasi,
  };

  factory EvaluasiProker.fromJson(Map<String, dynamic> j) => EvaluasiProker(
    id: j['id']?.toString() ?? '',
    prokerId: j['proker_id']?.toString() ?? '',
    namaProker: j['nama_proker']?.toString() ?? '',
    sekbid: j['sekbid']?.toString() ?? '',
    tanggalEvaluasi: DateTime.tryParse(j['tanggal_evaluasi']?.toString() ?? '') ?? DateTime.now(),
    hasilCapaian: j['hasil_capaian']?.toString() ?? '',
    kendala: j['kendala']?.toString() ?? '',
    saranMasukan: j['saran_masukan']?.toString() ?? '',
    nilaiKinerja: (j['nilai_kinerja'] as num?)?.toInt() ?? 85,
    penilai: j['penilai']?.toString() ?? 'Pembina OSIS',
    rekomendasi: j['rekomendasi']?.toString() ?? '',
  );
}

// ── 12.10. RIWAYAT AKTIVITAS PENGGUNA (AUDIT LOG) ──────────────────────────

class AktivitasPengguna {
  String id;
  String username;
  String displayName;
  String role;
  String aksi; // e.g. 'Tambah Proker', 'Update Kas', 'Buat Pengumuman', 'Catat Absensi'
  String modul; // e.g. 'Program Kerja', 'Keuangan', 'Pengumuman', 'Absensi'
  DateTime waktu;
  String detail;

  AktivitasPengguna({
    required this.id,
    required this.username,
    required this.displayName,
    this.role = '',
    required this.aksi,
    required this.modul,
    DateTime? waktu,
    this.detail = '',
  }) : waktu = waktu ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'role': role,
    'aksi': aksi,
    'modul': modul,
    'waktu': waktu.toIso8601String(),
    'detail': detail,
  };

  factory AktivitasPengguna.fromJson(Map<String, dynamic> j) => AktivitasPengguna(
    id: j['id']?.toString() ?? '',
    username: j['username']?.toString() ?? '',
    displayName: j['display_name']?.toString() ?? '',
    role: j['role']?.toString() ?? '',
    aksi: j['aksi']?.toString() ?? '',
    modul: j['modul']?.toString() ?? '',
    waktu: DateTime.tryParse(j['waktu']?.toString() ?? '') ?? DateTime.now(),
    detail: j['detail']?.toString() ?? '',
  );
}


