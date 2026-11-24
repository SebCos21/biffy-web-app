import '../../../data/models/address.dart';
import '../../../domain/usecases/orders/checkout_draft.dart';
import '../../../shared/state/session_controller.dart';
import '../../addresses/bloc/addresses_cubit.dart';
import '../../wallet/bloc/wallet_cubit.dart';
import 'bloc/cart_cubit.dart';

/// Dirección elegida para el carrito (o la predeterminada del usuario).
Address? cartAddress(
  SessionController session,
  CartCubit cart,
  AddressesCubit addresses,
) =>
    addresses.byId(session.user?.id, cart.addressId) ??
    addresses.defaultOf(session.user?.id);

/// Construye el borrador del checkout a partir del carrito actual; el cupón
/// sale de la billetera de la cuenta.
CheckoutDraft draftFromCart(
  SessionController session,
  CartCubit cart,
  WalletCubit wallet,
  AddressesCubit addresses,
) => CheckoutDraft(
      buyer: session.user,
      restaurant: cart.restaurant,
      items: cart.items,
      address: cartAddress(session, cart, addresses),
      payment: cart.payment ?? session.data.defaultPayment,
      scheduledFor: cart.scheduledFor,
      tip: cart.tip,
      useGotas: cart.useGotas && session.isLoggedIn,
      coupon: wallet.couponById(session.user?.id, cart.couponId),
      restaurantNote: cart.restaurantNote,
      cashTendered: cart.cashTendered,
    );
