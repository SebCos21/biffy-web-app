import 'package:biffy/core/constants/catalog_constants.dart';
import 'package:biffy/data/models/address.dart';
import 'package:biffy/data/repositories/in_memory_address_repository.dart';
import 'package:biffy/data/repositories/supabase_address_repository.dart';
import 'package:biffy/domain/repositories/address_repository.dart';
import 'package:biffy/domain/usecases/addresses/address_usecases.dart';
import 'package:biffy/features/addresses/bloc/addresses_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Dirección nueva (id vacío) en el punto indicado.
Address _address(String label, {String pointId = 'icesi-biblioteca'}) =>
    Address(
      id: '',
      label: label,
      line: '$label · línea',
      neighborhood: 'Campus',
      pointId: pointId,
    );

/// Coincide con un estado cuyo último resultado terminó con [code].
TypeMatcher<AddressesState> _outcome(String code) =>
    isA<AddressesState>().having((s) => s.outcome?.result.code, 'code', code);

/// Pruebas con bloc_test de las direcciones de entrega.
void main() {
  late InMemoryAddressRepository repo;
  setUp(() => repo = InMemoryAddressRepository());

  AddressesCubit cubit([AddressRepository? r]) =>
      AddressesCubit(AddressUseCases(repo: r ?? repo));

  group('AddressesCubit', () {
    blocTest<AddressesCubit, AddressesState>(
      'la primera dirección queda guardada con id y como predeterminada',
      build: cubit,
      act: (c) => c.save('u1', _address('Biblioteca')),
      expect: () => contains(_outcome('ok')),
      verify: (c) {
        final saved = c.addressesOf('u1').single;
        expect(saved.id, isNotEmpty);
        expect(c.defaultOf('u1')?.id, saved.id);
      },
    );

    blocTest<AddressesCubit, AddressesState>(
      'sin sesión no se guarda y emite el error en español',
      build: cubit,
      act: (c) => c.save(null, _address('Casa')),
      expect: () => [
        _outcome('not_logged_in').having(
          (s) => s.outcome?.result.message,
          'mensaje',
          'Inicia sesión para guardar direcciones.',
        ),
      ],
      verify: (c) => expect(c.addressesOf(null), isEmpty),
    );

    blocTest<AddressesCubit, AddressesState>(
      'borrar la predeterminada elige la siguiente',
      setUp: () async {
        await repo.save('u1', _address('A'), makeDefault: true);
        await repo.save('u1', _address('B'), makeDefault: false);
      },
      build: cubit,
      act: (c) => c.delete('u1', c.defaultOf('u1')!.id),
      expect: () => contains(_outcome('ok')),
      verify: (c) => expect(c.defaultOf('u1')?.label, 'B'),
    );

    blocTest<AddressesCubit, AddressesState>(
      'borrar una dirección que no existe emite not_found',
      build: cubit,
      act: (c) => c.delete('u1', 'no-existe'),
      expect: () => contains(_outcome('not_found')),
    );

    blocTest<AddressesCubit, AddressesState>(
      'marcar otra como predeterminada',
      setUp: () async {
        await repo.save('u1', _address('A'), makeDefault: true);
        await repo.save('u1', _address('B'), makeDefault: false);
      },
      build: cubit,
      act: (c) => c.setDefault(
        'u1',
        c.addressesOf('u1').firstWhere((a) => a.label == 'B').id,
      ),
      expect: () => contains(_outcome('ok')),
      verify: (c) => expect(c.defaultOf('u1')?.label, 'B'),
    );

    blocTest<AddressesCubit, AddressesState>(
      'con Supabase caído la dirección queda en el equipo y avisa network',
      build: () => cubit(
        SupabaseAddressRepository(
          client: sb.SupabaseClient('http://127.0.0.1:1', 'clave-falsa'),
        ),
      ),
      act: (c) => c.save('u1', _address('Casa')),
      expect: () => contains(_outcome('network')),
      verify: (c) => expect(c.addressesOf('u1').single.label, 'Casa'),
    );
  });

  test('editar una dirección conserva su uuid de la base', () async {
    final saved = (await repo.save(
      'u1',
      _address('Casa'),
      makeDefault: true,
    )).address!..dbId = 'uuid-1';
    // La pantalla de edición arma un objeto nuevo con el mismo id.
    await repo.save(
      'u1',
      Address(
        id: saved.id,
        label: 'Casa nueva',
        line: saved.line,
        neighborhood: saved.neighborhood,
        pointId: saved.pointId,
      ),
      makeDefault: false,
    );
    final edited = repo.addressesOf('u1').single;
    expect(edited.label, 'Casa nueva');
    expect(edited.dbId, 'uuid-1');
  });

  test('la dirección inicial del comprador es su punto de entrega', () async {
    final uc = AddressUseCases(repo: repo);
    final p = pointById('chapinero');
    await uc.createInitial('u1', p);
    final a = uc.queries.defaultOf('u1')!;
    expect(a.label, 'Punto de entrega');
    expect(a.pointId, 'chapinero');
    expect(a.neighborhood, 'Bogotá');
  });
}
