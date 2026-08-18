class BookingService {
  final String name;
  final double price;
  final String category;

  const BookingService({
    required this.name,
    required this.price,
    required this.category,
  });
}

const List<BookingService> bookingServices = [
  // Press-ons

  BookingService(name: 'Press-on installation', price: 100, category: 'Press-ons'),

  // Lashes
  BookingService(name: 'Cluster lashes', price: 200, category: 'Lashes'),
  BookingService(name: 'Classic lashes', price: 250, category: 'Lashes'),
  BookingService(name: 'Volume lashes', price: 300, category: 'Lashes'),
  BookingService(name: 'Hybrid lashes', price: 350, category: 'Lashes'),
  BookingService(name: 'Eyelash removal', price: 50, category: 'Lashes'),

  // Hair
  BookingService(name: 'Afro Crotchet', price: 350, category: 'Hair'),
  BookingService(name: 'Wig lines', price: 150, category: 'Hair'),
  BookingService(name: 'Wig installation', price: 400, category: 'Hair'),
  BookingService(name: 'Keratin Wig care', price: 250, category: 'Hair'),

  // Makeup
  BookingService(name: 'Eye brow care', price: 200, category: 'Makeup'),
  BookingService(name: 'Soft glam', price: 400, category: 'Makeup'),
  BookingService(name: 'Full glam', price: 500, category: 'Makeup'),
];