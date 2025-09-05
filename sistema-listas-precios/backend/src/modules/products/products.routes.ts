import { Router } from 'express';
import { listProductsController, getProductController, updateProductController } from './products.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';

const router = Router();

// Se requiere auth para ver productos (aplica descuento del usuario)
router.use(authGuard);

router.get('/', listProductsController);
router.get('/:id', getProductController);

// EdiciÃ³n sÃ³lo admin
router.patch('/:id', adminGuard, updateProductController);

export default router;
