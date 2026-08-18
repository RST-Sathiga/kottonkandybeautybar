class BookingService {
  final String name;
  final double price;

  const BookingService({
    required this.name,
    required this.price,
  });
}

const List<BookingService> bookingServices = [
  BookingService(
    name: 'Acrylic - Short',
    price: 350,
  ),
  BookingService(
    name: 'Acrylic - Medium',
    price: 400,
  ),
  BookingService(
    name: 'Acrylic - Long',
    price: 450,
  ),
  BookingService(
    name: 'Gel - Hands',
    price: 350,
  ),
  BookingService(
    name: 'Gel - Toes',
    price: 300,
  ),
  BookingService(
    name: 'Gel Combo - Hands & Toes',
    price: 550,
  ),
  BookingService(
    name: 'Gents Buff & Shine',
    price: 250,
  ),
];