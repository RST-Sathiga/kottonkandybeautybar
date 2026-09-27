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
    id: 'press_on_plain',
    name: 'Press-on Plain',
    price: 250.00,
    category: 'Press-ons',
    description: 'Clean, simple, solid-color press-on set application.',
    duration: '45 mins',
  ),
  BookingService(
    id: 'press_on_glam',
    name: 'Press-on Glam',
    price: 350.00,
    category: 'Press-ons',
    description: 'Glamorous press-on set with intricate design elements.',
    duration: '1 hour',
  ),
  BookingService(
    id: 'press_on_installation',
    name: 'Press-on Installation',
    price: 100.00,
    category: 'Press-ons',
    description: 'Professional sizing, prep, and long-lasting application.',
    duration: '30 mins',
  ),

  // ============================================================
  // LASHES
  // ============================================================
  BookingService(
    id: 'cluster_lashes',
    name: 'Cluster Lashes',
    price: 200.00,
    category: 'Lashes',
    description: 'Full, beautiful cluster lash application.',
    duration: '45 mins',
  ),
  BookingService(
    id: 'classic_lashes',
    name: 'Classic Lashes',
    price: 250.00,
    category: 'Lashes',
    description: 'Natural-looking individual lash extensions.',
    duration: '1 hour 30 mins',
  ),
  BookingService(
    id: 'volume_lashes',
    name: 'Volume Lashes',
    price: 300.00,
    category: 'Lashes',
    description: 'Full and fluffy volume lash extensions.',
    duration: '2 hours',
  ),
  BookingService(
    id: 'hybrid_lashes',
    name: 'Hybrid Lashes',
    price: 350.00,
    category: 'Lashes',
    description: 'Combination of classic and volume techniques.',
    duration: '1 hour 45 mins',
  ),
  BookingService(
    id: 'eyelash_removal',
    name: 'Eyelash Removal',
    price: 50.00,
    category: 'Lashes',
    description: 'Safe and gentle removal of existing lash extensions.',
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
    description: 'Neat and lightweight Afro crotchet installation.',
    duration: '2 hours',
  ),
  BookingService(
    id: 'wig_lines',
    name: 'Wig Lines',
    price: 150.00,
    category: 'Hair',
    description: 'Flat, secure cornrow base for comfortable wig wear.',
    duration: '45 mins',
  ),
  BookingService(
    id: 'wig_installation',
    name: 'Wig Installation',
    price: 400.00,
    category: 'Hair',
    description: 'Professional wig fitting, melting, and styling.',
    duration: '1 hour 30 mins',
  ),
  BookingService(
    id: 'keratin_wig_care',
    name: 'Keratin Wig Care',
    price: 250.00,
    category: 'Hair',
    description: 'Restorative keratin wash, deep condition, and revival.',
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
    description: 'Precision eyebrow shaping, trimming, and grooming.',
    duration: '30 mins',
  ),
  BookingService(
    id: 'soft_glam',
    name: 'Soft Glam',
    price: 400.00,
    category: 'Makeup',
    description: 'Seamless, radiant neutral glam makeup.',
    duration: '1 hour',
  ),
  BookingService(
    id: 'full_glam',
    name: 'Full Glam',
    price: 500.00,
    category: 'Makeup',
    description: 'Full coverage, dramatic eye look, cut crease, and lashes.',
    duration: '1 hour 30 mins',
  ),
];