import { Router } from 'express';
import { listSuppliersController, createSupplierController, updateSupplierController } from './suppliers.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';

const router = Router();

// SÃ³lo admin por ahora para listar/gestionar proveedores.
router.use(authGuard, adminGuard);

router.get('/', listSuppliersController);
router.post('/', createSupplierController);
router.patch('/:id', updateSupplierController);

export default router;
