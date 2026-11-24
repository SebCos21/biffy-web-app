import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PNG de 1×1 para probar Storage sin archivos externos.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Uuid que no existe: los DELETE prohibidos no borran nada aunque fallen
/// las protecciones (la base es compartida).
const _noRow = '00000000-0000-0000-0000-000000000000';

/// Pruebas de RLS de la HU-2 (catálogo entre comercios) contra el proyecto
/// real. Requieren `0019_catalog_hu2.sql` aplicada y se saltan sin
/// credenciales:
///
/// ```bash
/// flutter test test/integration/hu2_supabase_test.dart \
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///   --dart-define=SUPABASE_KEY=sb_publishable_...
/// ```
///
/// No dejan datos: las escrituras permitidas se limitan a una foto de prueba
/// que se borra al final.
void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_KEY');
  final enabled = url.isNotEmpty && key.isNotEmpty;

  group(
    'HU-2 · catálogo y RLS entre comercios',
    () {
      late SupabaseClient qbano;
      late SupabaseClient horno;
      late SupabaseClient buyer;
      late String qbanoUser;
      late String buyerId;
      late String qbanoBiz;
      late String hornoBiz;
      late String hornoBranch;
      late String hornoDish;
      late String qbanoDish;

      /// Negocio de la cuenta, leído de su perfil.
      Future<String> businessOf(SupabaseClient c, String userId) async {
        final row = await c
            .from('profiles')
            .select('business_id')
            .eq('id', userId)
            .single();
        return row['business_id'] as String;
      }

      /// Primera sede activa de un negocio.
      Future<String> branchOf(SupabaseClient c, String businessId) async {
        final row = await c
            .from('branches')
            .select('id')
            .eq('business_id', businessId)
            .limit(1)
            .single();
        return row['id'] as String;
      }

      /// Primer plato de una sede.
      Future<String> dishOf(SupabaseClient c, String branchId) async {
        final row = await c
            .from('dishes')
            .select('id')
            .eq('branch_id', branchId)
            .limit(1)
            .single();
        return row['id'] as String;
      }

      /// Inicia sesión con las dos cuentas de comercio y el comprador.
      setUpAll(() async {
        qbano = SupabaseClient(url, key);
        horno = SupabaseClient(url, key);
        buyer = SupabaseClient(url, key);

        qbanoUser = (await qbano.auth.signInWithPassword(
          email: 'qbano@demo.biffy.co',
          password: 'biffy123',
        )).user!.id;
        final hornoUser = (await horno.auth.signInWithPassword(
          email: 'horno@demo.biffy.co',
          password: 'biffy123',
        )).user!.id;
        buyerId = (await buyer.auth.signInWithPassword(
          email: 'diego.demo@icesi.edu.co',
          password: 'biffy123',
        )).user!.id;

        qbanoBiz = await businessOf(qbano, qbanoUser);
        hornoBiz = await businessOf(horno, hornoUser);
        hornoBranch = await branchOf(horno, hornoBiz);
        hornoDish = await dishOf(horno, hornoBranch);
        qbanoDish = await dishOf(qbano, await branchOf(qbano, qbanoBiz));
      });

      /// Cierra las tres sesiones.
      tearDownAll(() async {
        await qbano.auth.signOut();
        await horno.auth.signOut();
        await buyer.auth.signOut();
      });

      test('cada comercio ve solo su negocio', () async {
        final q = await qbano.from('businesses').select('id');
        final h = await horno.from('businesses').select('id');
        expect(q.map((r) => r['id']), [qbanoBiz]);
        expect(h.map((r) => r['id']), [hornoBiz]);
      });

      test('Qbano no edita la sede ni el plato de Horno', () async {
        final branch = await qbano
            .from('branches')
            .update({'tagline': 'hackeada'})
            .eq('id', hornoBranch)
            .select('id');
        final dish = await qbano
            .from('dishes')
            .update({'price': 1})
            .eq('id', hornoDish)
            .select('id');
        final options = await qbano
            .from('dish_options')
            .update({'label': 'hackeada'})
            .eq('dish_id', hornoDish)
            .select('id');
        expect(branch, isEmpty);
        expect(dish, isEmpty);
        expect(options, isEmpty);
      });

      test('Qbano no crea en la sede ni en el negocio de Horno', () async {
        await expectLater(
          qbano.from('dishes').insert({
            'branch_id': hornoBranch,
            'name': 'intruso',
            'price': 1,
            'category_id': 'almuerzo',
          }),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          qbano.from('branches').insert({
            'business_id': hornoBiz,
            'name': 'intrusa',
          }),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          qbano
              .from('dishes')
              .update({'branch_id': hornoBranch})
              .eq('id', qbanoDish),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('el DELETE duro está prohibido', () async {
        for (final table in ['dishes', 'branches', 'businesses']) {
          await expectLater(
            qbano.from(table).delete().eq('id', _noRow),
            throwsA(isA<PostgrestException>()),
            reason: table,
          );
        }
      });

      test('el comprador no lee businesses y la vista es mínima', () async {
        final own = await buyer.from('businesses').select('id');
        expect(own, isEmpty);

        final public = await buyer.from('businesses_public').select().limit(1);
        expect(public, isNotEmpty);
        expect(public.first.keys.toSet(), {
          'id',
          'brand',
          'cuisine',
          'description',
        });
      });

      test('el comprador solo ve platos activos y sedes vivas', () async {
        final dishes = await buyer.from('dishes').select('active, deleted_at');
        final branches = await buyer.from('branches').select('deleted_at');
        expect(dishes, isNotEmpty);
        expect(dishes.every((d) => d['active'] == true), isTrue);
        expect(dishes.every((d) => d['deleted_at'] == null), isTrue);
        expect(branches.every((b) => b['deleted_at'] == null), isTrue);
      });

      test('catalog_revision es legible y no escribible', () async {
        final row = await buyer
            .from('catalog_revision')
            .select('rev')
            .eq('id', 1)
            .single();
        expect(row['rev'], isA<int>());
        await expectLater(
          buyer
              .from('catalog_revision')
              .update({'rev': 0})
              .eq('id', 1)
              .select('id'),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('los favoritos son privados', () async {
        final mine = await buyer.from('favorite_dishes').select('user_id');
        expect(mine.every((r) => r['user_id'] == buyerId), isTrue);
        final branches = await buyer
            .from('favorite_branches')
            .select('user_id');
        expect(branches.every((r) => r['user_id'] == buyerId), isTrue);

        await expectLater(
          buyer.from('favorite_dishes').insert({
            'user_id': qbanoUser,
            'dish_id': qbanoDish,
          }),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('Storage: cada comercio sube solo a su carpeta', () async {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        const options = FileOptions(contentType: 'image/png');

        await expectLater(
          qbano.storage
              .from('dish-images')
              .uploadBinary(
                '$hornoBiz/hu2-$stamp.png',
                _png,
                fileOptions: options,
              ),
          throwsA(isA<StorageException>()),
        );

        final ownPath = '$qbanoBiz/hu2-$stamp.png';
        await qbano.storage
            .from('dish-images')
            .uploadBinary(ownPath, _png, fileOptions: options);
        try {
          final removed = await horno.storage.from('dish-images').remove([
            ownPath,
          ]);
          expect(removed, isEmpty, reason: 'Horno no borra fotos de Qbano');
        } finally {
          await qbano.storage.from('dish-images').remove([ownPath]);
        }
      });
    },
    skip: enabled
        ? false
        : 'Requiere --dart-define=SUPABASE_URL y SUPABASE_KEY',
  );
}
