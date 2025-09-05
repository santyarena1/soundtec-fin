import { Router } from 'express';
import { listUsersController, createUserController, updateUserController } from './users.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';

const router = Router();

// Todas las rutas de /users son sÃ³lo para ADMIN
router.use(authGuard, adminGuard);

router.get('/', listUsersController);
router.post('/', createUserController);
router.patch('/:id', updateUserController);

export default router;
