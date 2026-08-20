class BookingService {
  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final String duration;

  const BookingService({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    required this.duration,
  });
}

const List<BookingService> bookingServices = [
  // ============================================================
  // PRESS-ONS
  // ============================================================

  BookingService(
    id: 'press_on_install',
    name: 'Press-on Installation',
    price: 100.00,
    category: 'Press-ons',
    description:
    'Professional sizing, preparation and application of press-on nails.',
    duration: '45 mins',
  ),

  // ============================================================
  // LASHES
  // ============================================================

  BookingService(
    id: 'cluster_lashes',
    name: 'Cluster Lashes',
    price: 200.00,
    category: 'Lashes',
    description:
    'Beautiful cluster lash application for a fuller look.',
    duration: '45 mins',
  ),

  BookingService(
    id: 'classic_lashes',
    name: 'Classic Lashes',
    price: 250.00,
    category: 'Lashes',
    description:
    'Natural-looking individual lash extensions.',
    duration: '1 hour 30 mins',
  ),

  BookingService(
    id: 'volume_lashes',
    name: 'Volume Lashes',
    price: 300.00,
    category: 'Lashes',
    description:
    'Full and glamorous volume lash extensions.',
    duration: '2 hours',
  ),

  BookingService(
    id: 'hybrid_lashes',
    name: 'Hybrid Lashes',
    price: 350.00,
    category: 'Lashes',
    description:
    'A combination of classic and volume lash techniques.',
    duration: '1 hour 45 mins',
  ),

  BookingService(
    id: 'eyelash_removal',
    name: 'Eyelash Removal',
    price: 50.00,
    category: 'Lashes',
    description:
    'Professional and gentle removal of lash extensions.',
    duration: '30 mins',
  ),

  // ============================================================
  // HAIR
  // ============================================================

  BookingService(
    id: 'afro_crotchet',
    name: 'Afro Crotchet',
    price: 350.00,
    category: 'Hair',
    description:
    'Professional Afro crotchet installation.',
    duration: '2 hours',
  ),

  BookingService(
    id: 'wig_lines',
    name: 'Wig Lines',
    price: 150.00,
    category: 'Hair',
    description:
    'Neat and secure wig-line preparation.',
    duration: '45 mins',
  ),

  BookingService(
    id: 'wig_installation',
    name: 'Wig Installation',
    price: 400.00,
    category: 'Hair',
    description:
    'Professional wig installation and styling.',
    duration: '1 hour 30 mins',
  ),

  BookingService(
    id: 'keratin_wig_care',
    name: 'Keratin Wig Care',
    price: 250.00,
    category: 'Hair',
    description:
    'Professional keratin treatment and wig maintenance.',
    duration: '1 hour',
  ),

  // ============================================================
  // MAKEUP
  // ============================================================

  BookingService(
    id: 'eye_brow_care',
    name: 'Eye Brow Care',
    price: 200.00,
    category: 'Makeup',
    description:
    'Professional eyebrow shaping and grooming.',
    duration: '30 mins',
  ),

  BookingService(
    id: 'soft_glam',
    name: 'Soft Glam',
    price: 400.00,
    category: 'Makeup',
    description:
    'Elegant soft glam makeup for any occasion.',
    duration: '1 hour',
  ),

  BookingService(
    id: 'full_glam',
    name: 'Full Glam',
    price: 500.00,
    category: 'Makeup',
    description:
    'Full professional glam makeup application.',
    duration: '1 hour 30 mins',
  ),
];